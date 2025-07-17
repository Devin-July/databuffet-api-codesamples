/*
 * Data Buffet API Vintage Filter Example
 * SAS Implementation demonstrating vintage filtering with predefined baskets
 * 
 * This example demonstrates two approaches for applying vintage filters:
 * 1. Direct vintage parameters on individual series endpoints
 * 2. Basket execution workflow (if direct vintage parameters are not supported)
 */

%include "api-auth.sas";
%include "basket-execution.sas";

/*
 * Configuration Section
 * Replace with your actual Data Buffet API credentials
 */
%let access_key = XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX;
%let encryption_key = XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX;
%let auth_method = HMAC;

%let target_basket_name = Test Basket;
%let vintage_filter = 202003;
%let vintage_version = 1;

%put NOTE: =================================================================;
%put NOTE: Data Buffet API Vintage Filter Example;
%put NOTE: This example demonstrates vintage filtering with predefined baskets;
%put NOTE: =================================================================;

/*
 * Step 1: Authentication Setup
 */
%put NOTE: Step 1 - Setting up authentication...;

%if %upcase(&auth_method.) = OAUTH %then %do;
    %local oauth_token;
    %get_oauth_token(&access_key., &encryption_key., oauth_token);
    
    %if %length(&oauth_token.) = 0 %then %do;
        %put ERROR: Failed to obtain OAuth token. Exiting.;
        %goto exit_program;
    %end;
    
    %put NOTE: OAuth token obtained successfully.;
%end;
%else %do;
    %put NOTE: Using HMAC authentication.;
%end;

/*
 * Step 2: List Available Baskets
 */
%put NOTE: Step 2 - Retrieving list of available baskets...;

%list_baskets(&access_key., &encryption_key., 
              auth_method=&auth_method., oauth_token=&oauth_token.,
              output_dataset=available_baskets);

proc print data=available_baskets(obs=10);
    title "Available Baskets (First 10)";
    var basketId name description;
run;

/*
 * Step 3: Find Target Basket
 */
%put NOTE: Step 3 - Finding target basket: &target_basket_name...;

%local target_basket_id basket_found;
%let basket_found = 0;

data _null_;
    set available_baskets;
    if upcase(name) = upcase("&target_basket_name.") then do;
        call symputx("target_basket_id", basketId);
        call symputx("basket_found", "1");
        stop;
    end;
run;

%if &basket_found. = 0 %then %do;
    %put WARNING: Target basket "&target_basket_name." not found.;
    %put NOTE: Using first available basket for demonstration...;
    
    data _null_;
        set available_baskets(obs=1);
        call symputx("target_basket_id", basketId);
        call symputx("target_basket_name", name);
    run;
%end;

%put NOTE: Selected basket: &target_basket_name. (ID: &target_basket_id.);

/*
 * Step 4: Get Basket Details
 */
%put NOTE: Step 4 - Retrieving basket details...;

%get_basket_info(&target_basket_id., &access_key., &encryption_key.,
                 auth_method=&auth_method., oauth_token=&oauth_token.,
                 output_dataset=basket_details);

proc print data=basket_details;
    title "Basket Details for &target_basket_name.";
run;

/*
 * APPROACH 1: Direct Vintage Parameters on Series Endpoints
 * This approach demonstrates retrieving individual series with vintage filters
 */
%put NOTE: =================================================================;
%put NOTE: APPROACH 1: Direct Vintage Parameters on Series Endpoints;
%put NOTE: =================================================================;

%macro get_series_with_vintage(mnemonic, vintage, vintage_version, access_key, encryption_key, 
                               auth_method=HMAC, oauth_token=, output_dataset=series_data);
    /*
     * Retrieves a single series with vintage filtering
     */
    
    %local api_url temp_file auth_headers;
    %let api_url = https://api.economy.com/data/v1/series?m=&mnemonic.;
    
    %if %length(&vintage.) > 0 %then %do;
        %let api_url = &api_url.%str(&)vintage=&vintage.;
    %end;
    
    %if %length(&vintage_version.) > 0 %then %do;
        %let api_url = &api_url.%str(&)vintageVersion=&vintage_version.;
    %end;
    
    %let temp_file = %sysfunc(pathname(work))/series_response.json;
    
    %if %upcase(&auth_method.) = HMAC %then %do;
        %setup_hmac_headers(&access_key., &encryption_key., auth_headers);
    %end;
    %else %if %upcase(&auth_method.) = OAUTH %then %do;
        %setup_oauth_headers(&oauth_token., auth_headers);
    %end;
    
    filename series_out "&temp_file.";
    
    proc http
        url="&api_url."
        method="GET"
        out=series_out;
        headers
            &auth_headers.
            "Content-Type" = "application/json"
            "Accept" = "application/json";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        libname series_lib json fileref=series_out;
        
        data &output_dataset.;
            set series_lib.root;
        run;
        
        libname series_lib clear;
        %put NOTE: Successfully retrieved series &mnemonic. with vintage &vintage..;
    %end;
    %else %do;
        %put ERROR: Failed to retrieve series &mnemonic. with vintage &vintage.. Status: &SYS_PROCHTTP_STATUS_CODE.;
    %end;
    
    filename series_out clear;
%mend get_series_with_vintage;

%put NOTE: Demonstrating vintage filtering on individual series...;

%get_series_with_vintage(ET.IUSA, &vintage_filter., &vintage_version., 
                        &access_key., &encryption_key.,
                        auth_method=&auth_method., oauth_token=&oauth_token.,
                        output_dataset=vintage_series_example);

proc print data=vintage_series_example;
    title "Series ET.IUSA with Vintage Filter &vintage_filter.";
    var mnemonic description startDate endDate;
run;

/*
 * APPROACH 2: Basket Execution Workflow
 * This approach demonstrates executing a predefined basket and retrieving results
 * Note: Direct vintage parameters may not be supported on basket execution endpoints
 */
%put NOTE: =================================================================;
%put NOTE: APPROACH 2: Basket Execution Workflow;
%put NOTE: =================================================================;

%put NOTE: Executing basket with standard workflow...;

/*
 * Step 5: Execute the Basket
 */
%put NOTE: Step 5 - Executing basket &target_basket_name...;

%local execution_order_id;
%execute_basket(&target_basket_id., &access_key., &encryption_key.,
                auth_method=&auth_method., oauth_token=&oauth_token.,
                order_id_var=execution_order_id);

%if %length(&execution_order_id.) = 0 %then %do;
    %put ERROR: Failed to execute basket. Exiting.;
    %goto exit_program;
%end;

/*
 * Step 6: Wait for Completion
 */
%put NOTE: Step 6 - Waiting for basket execution to complete...;

%wait_for_order_completion(&execution_order_id., &access_key., &encryption_key.,
                          auth_method=&auth_method., oauth_token=&oauth_token.,
                          sleep_seconds=5, max_wait_minutes=10);

/*
 * Step 7: Retrieve Results
 */
%put NOTE: Step 7 - Retrieving basket execution results...;

%retrieve_basket_output(&target_basket_id., &access_key., &encryption_key.,
                       auth_method=&auth_method., oauth_token=&oauth_token.,
                       output_file=%sysfunc(pathname(work))/basket_output.csv,
                       output_dataset=basket_results);

%if %sysfunc(exist(basket_results)) %then %do;
    proc print data=basket_results(obs=20);
        title "Basket Execution Results (First 20 Observations)";
    run;
%end;

/*
 * APPROACH 2B: Alternative Vintage Filtering via Basket Modification
 * This demonstrates how to potentially apply vintage filters by modifying basket series
 */
%put NOTE: =================================================================;
%put NOTE: APPROACH 2B: Basket Modification for Vintage Filtering;
%put NOTE: =================================================================;

%macro modify_basket_for_vintage(basket_id, vintage, access_key, encryption_key,
                                auth_method=HMAC, oauth_token=);
    /*
     * Demonstrates how to modify a basket to apply vintage filtering
     * Note: This is a conceptual implementation - actual API support may vary
     */
    
    %put NOTE: This approach would involve:;
    %put NOTE: 1. Getting current basket contents;
    %put NOTE: 2. Modifying series definitions to include vintage parameters;
    %put NOTE: 3. Updating the basket with modified series;
    %put NOTE: 4. Executing the modified basket;
    %put NOTE: 5. Restoring original basket if needed;
    
    %put WARNING: Direct vintage parameter support on basket execution is uncertain.;
    %put WARNING: This approach requires further API documentation review.;
    
    %local api_url temp_file auth_headers;
    %let api_url = https://api.economy.com/data/v1/baskets/&basket_id./contents;
    %let temp_file = %sysfunc(pathname(work))/basket_contents.json;
    
    %if %upcase(&auth_method.) = HMAC %then %do;
        %setup_hmac_headers(&access_key., &encryption_key., auth_headers);
    %end;
    %else %if %upcase(&auth_method.) = OAUTH %then %do;
        %setup_oauth_headers(&oauth_token., auth_headers);
    %end;
    
    filename contents_out "&temp_file.";
    
    proc http
        url="&api_url."
        method="GET"
        out=contents_out;
        headers
            &auth_headers.
            "Content-Type" = "application/json"
            "Accept" = "application/json";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        %put NOTE: Successfully retrieved basket contents for modification analysis.;
        
        libname contents_lib json fileref=contents_out;
        
        data basket_contents;
            set contents_lib.root;
        run;
        
        libname contents_lib clear;
        
        proc print data=basket_contents;
            title "Current Basket Contents for Vintage Analysis";
        run;
    %end;
    %else %do;
        %put ERROR: Failed to retrieve basket contents. Status: &SYS_PROCHTTP_STATUS_CODE.;
    %end;
    
    filename contents_out clear;
%mend modify_basket_for_vintage;

%modify_basket_for_vintage(&target_basket_id., &vintage_filter., 
                          &access_key., &encryption_key.,
                          auth_method=&auth_method., oauth_token=&oauth_token.);

/*
 * Summary and Recommendations
 */
%put NOTE: =================================================================;
%put NOTE: SUMMARY AND RECOMMENDATIONS;
%put NOTE: =================================================================;

%put NOTE: Vintage Filtering Implementation Summary:;
%put NOTE: ;
%put NOTE: APPROACH 1 - Direct Series Vintage Parameters:;
%put NOTE: - Works with /series and /multi-series endpoints;
%put NOTE: - Supports vintage parameter (YYYYMM, YYYYQ#, YYYY format);
%put NOTE: - Supports vintageVersion parameter (1, 2, 3, etc.);
%put NOTE: - Best for retrieving specific vintage versions of individual series;
%put NOTE: ;
%put NOTE: APPROACH 2 - Basket Execution Workflow:;
%put NOTE: - Standard basket execution without direct vintage parameters;
%put NOTE: - Asynchronous processing with order status polling;
%put NOTE: - Retrieves current/latest data from predefined basket;
%put NOTE: - May require basket modification for vintage filtering;
%put NOTE: ;
%put NOTE: RECOMMENDATIONS:;
%put NOTE: 1. Use Approach 1 for individual series with specific vintage requirements;
%put NOTE: 2. Use Approach 2 for bulk data retrieval from predefined baskets;
%put NOTE: 3. Consider hybrid approach: execute basket, then apply vintage filters to specific series;
%put NOTE: 4. Consult Data Buffet API documentation for latest vintage filtering capabilities;

%exit_program:
%put NOTE: =================================================================;
%put NOTE: Vintage Filter Example Complete;
%put NOTE: =================================================================;
