/*
 * Data Buffet API Basket Operations
 * SAS Implementation for Basket Management and Execution
 * 
 * This file provides macros for managing and executing Data Buffet baskets,
 * including listing, execution, status monitoring, and output retrieval.
 */

%macro list_baskets(access_key, encryption_key, auth_method=HMAC, oauth_token=, output_dataset=baskets);
    /*
     * Retrieves list of available baskets from Data Buffet API
     * 
     * Parameters:
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   auth_method: Authentication method (HMAC or OAUTH, default: HMAC)
     *   oauth_token: OAuth token (required if auth_method=OAUTH)
     *   output_dataset: Name of output dataset to store basket list (default: baskets)
     *
     * Example:
     *   %list_baskets(&access_key, &encryption_key, output_dataset=my_baskets);
     */
    
    %local api_url temp_file auth_headers;
    %let api_url = https://api.economy.com/data/v1/baskets;
    %let temp_file = %sysfunc(pathname(work))/baskets_response.json;
    
    %if %upcase(&auth_method.) = HMAC %then %do;
        %setup_hmac_headers(&access_key., &encryption_key., auth_headers);
    %end;
    %else %if %upcase(&auth_method.) = OAUTH %then %do;
        %setup_oauth_headers(&oauth_token., auth_headers);
    %end;
    
    filename basket_out "&temp_file.";
    
    proc http
        url="&api_url."
        method="GET"
        out=basket_out;
        headers
            &auth_headers.
            "Content-Type" = "application/json"
            "Accept" = "application/json";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        libname basket_lib json fileref=basket_out;
        
        data &output_dataset.;
            set basket_lib.root;
        run;
        
        libname basket_lib clear;
        %put NOTE: Successfully retrieved basket list. Dataset &output_dataset. created.;
    %end;
    %else %do;
        %put ERROR: Failed to retrieve baskets. Status code: &SYS_PROCHTTP_STATUS_CODE.;
    %end;
    
    filename basket_out clear;
%mend list_baskets;

%macro get_basket_info(basket_id, access_key, encryption_key, auth_method=HMAC, oauth_token=, output_dataset=basket_info);
    /*
     * Retrieves detailed information about a specific basket
     * 
     * Parameters:
     *   basket_id: ID of the basket to retrieve information for
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   auth_method: Authentication method (HMAC or OAUTH, default: HMAC)
     *   oauth_token: OAuth token (required if auth_method=OAUTH)
     *   output_dataset: Name of output dataset to store basket info (default: basket_info)
     *
     * Example:
     *   %get_basket_info(85B9FE18-F619-4786-953A-7ECF42936C87, &access_key, &encryption_key);
     */
    
    %local api_url temp_file auth_headers;
    %let api_url = https://api.economy.com/data/v1/baskets/&basket_id.;
    %let temp_file = %sysfunc(pathname(work))/basket_info_response.json;
    
    %if %upcase(&auth_method.) = HMAC %then %do;
        %setup_hmac_headers(&access_key., &encryption_key., auth_headers);
    %end;
    %else %if %upcase(&auth_method.) = OAUTH %then %do;
        %setup_oauth_headers(&oauth_token., auth_headers);
    %end;
    
    filename info_out "&temp_file.";
    
    proc http
        url="&api_url."
        method="GET"
        out=info_out;
        headers
            &auth_headers.
            "Content-Type" = "application/json"
            "Accept" = "application/json";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        libname info_lib json fileref=info_out;
        
        data &output_dataset.;
            set info_lib.root;
        run;
        
        libname info_lib clear;
        %put NOTE: Successfully retrieved basket info for &basket_id.. Dataset &output_dataset. created.;
    %end;
    %else %do;
        %put ERROR: Failed to retrieve basket info for &basket_id.. Status code: &SYS_PROCHTTP_STATUS_CODE.;
    %end;
    
    filename info_out clear;
%mend get_basket_info;

%macro execute_basket(basket_id, access_key, encryption_key, auth_method=HMAC, oauth_token=, order_id_var=order_id);
    /*
     * Executes a basket and returns the order ID for status monitoring
     * 
     * Parameters:
     *   basket_id: ID of the basket to execute
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   auth_method: Authentication method (HMAC or OAUTH, default: HMAC)
     *   oauth_token: OAuth token (required if auth_method=OAUTH)
     *   order_id_var: Name of macro variable to store the returned order ID
     *
     * Example:
     *   %execute_basket(85B9FE18-F619-4786-953A-7ECF42936C87, &access_key, &encryption_key, order_id_var=my_order);
     */
    
    %local api_url temp_file auth_headers;
    %let api_url = https://api.economy.com/data/v1/orders?id=&basket_id.%str(&)type=baskets%str(&)action=run;
    %let temp_file = %sysfunc(pathname(work))/execute_response.json;
    
    %if %upcase(&auth_method.) = HMAC %then %do;
        %setup_hmac_headers(&access_key., &encryption_key., auth_headers);
    %end;
    %else %if %upcase(&auth_method.) = OAUTH %then %do;
        %setup_oauth_headers(&oauth_token., auth_headers);
    %end;
    
    filename exec_out "&temp_file.";
    
    proc http
        url="&api_url."
        method="POST"
        out=exec_out;
        headers
            &auth_headers.
            "Content-Type" = "application/json"
            "Accept" = "application/json"
            "Content-Length" = "0";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        libname exec_lib json fileref=exec_out;
        
        data _null_;
            set exec_lib.root;
            call symputx("&order_id_var.", orderId);
        run;
        
        libname exec_lib clear;
        %put NOTE: Successfully executed basket &basket_id.. Order ID: &&&order_id_var..;
    %end;
    %else %do;
        %put ERROR: Failed to execute basket &basket_id.. Status code: &SYS_PROCHTTP_STATUS_CODE.;
        %let &order_id_var. = ;
    %end;
    
    filename exec_out clear;
%mend execute_basket;

%macro check_order_status(order_id, access_key, encryption_key, auth_method=HMAC, oauth_token=, status_var=order_status, finished_var=order_finished);
    /*
     * Checks the status of a basket execution order
     * 
     * Parameters:
     *   order_id: ID of the order to check
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   auth_method: Authentication method (HMAC or OAUTH, default: HMAC)
     *   oauth_token: OAuth token (required if auth_method=OAUTH)
     *   status_var: Name of macro variable to store order status
     *   finished_var: Name of macro variable to store completion flag (1=finished, 0=processing)
     *
     * Example:
     *   %check_order_status(&order_id, &access_key, &encryption_key);
     */
    
    %local api_url temp_file auth_headers;
    %let api_url = https://api.economy.com/data/v1/orders/&order_id.;
    %let temp_file = %sysfunc(pathname(work))/status_response.json;
    
    %if %upcase(&auth_method.) = HMAC %then %do;
        %setup_hmac_headers(&access_key., &encryption_key., auth_headers);
    %end;
    %else %if %upcase(&auth_method.) = OAUTH %then %do;
        %setup_oauth_headers(&oauth_token., auth_headers);
    %end;
    
    filename status_out "&temp_file.";
    
    proc http
        url="&api_url."
        method="GET"
        out=status_out;
        headers
            &auth_headers.
            "Content-Type" = "application/json"
            "Accept" = "application/json";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        libname status_lib json fileref=status_out;
        
        data _null_;
            set status_lib.root;
            call symputx("&status_var.", processing);
            if missing(dateFinished) then call symputx("&finished_var.", "0");
            else call symputx("&finished_var.", "1");
        run;
        
        libname status_lib clear;
    %end;
    %else %do;
        %put ERROR: Failed to check order status for &order_id.. Status code: &SYS_PROCHTTP_STATUS_CODE.;
        %let &status_var. = ERROR;
        %let &finished_var. = 0;
    %end;
    
    filename status_out clear;
%mend check_order_status;

%macro wait_for_order_completion(order_id, access_key, encryption_key, auth_method=HMAC, oauth_token=, sleep_seconds=10, max_wait_minutes=30);
    /*
     * Waits for basket execution order to complete with polling
     * 
     * Parameters:
     *   order_id: ID of the order to monitor
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   auth_method: Authentication method (HMAC or OAUTH, default: HMAC)
     *   oauth_token: OAuth token (required if auth_method=OAUTH)
     *   sleep_seconds: Seconds to wait between status checks (default: 10)
     *   max_wait_minutes: Maximum minutes to wait before timeout (default: 30)
     *
     * Example:
     *   %wait_for_order_completion(&order_id, &access_key, &encryption_key, sleep_seconds=5);
     */
    
    %local finished_flag wait_count max_iterations current_status;
    %let finished_flag = 0;
    %let wait_count = 0;
    %let max_iterations = %eval(&max_wait_minutes. * 60 / &sleep_seconds.);
    
    %put NOTE: Waiting for order &order_id. to complete. Checking every &sleep_seconds. seconds...;
    
    %do %while(&finished_flag. = 0 and &wait_count. < &max_iterations.);
        %check_order_status(&order_id., &access_key., &encryption_key., 
                           auth_method=&auth_method., oauth_token=&oauth_token.,
                           status_var=current_status, finished_var=finished_flag);
        
        %if &finished_flag. = 0 %then %do;
            %let wait_count = %eval(&wait_count. + 1);
            %put NOTE: Order still processing... (check &wait_count. of &max_iterations.);
            
            data _null_;
                call sleep(&sleep_seconds.);
            run;
        %end;
    %end;
    
    %if &finished_flag. = 1 %then %do;
        %put NOTE: Order &order_id. completed successfully!;
    %end;
    %else %do;
        %put WARNING: Order &order_id. did not complete within &max_wait_minutes. minutes. Check status manually.;
    %end;
%mend wait_for_order_completion;

%macro retrieve_basket_output(basket_id, access_key, encryption_key, auth_method=HMAC, oauth_token=, output_file=, output_dataset=basket_data);
    /*
     * Retrieves the output from a completed basket execution
     * 
     * Parameters:
     *   basket_id: ID of the basket to retrieve output for
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   auth_method: Authentication method (HMAC or OAUTH, default: HMAC)
     *   oauth_token: OAuth token (required if auth_method=OAUTH)
     *   output_file: Optional - file path to save raw output
     *   output_dataset: Name of output dataset for JSON data (default: basket_data)
     *
     * Example:
     *   %retrieve_basket_output(85B9FE18-F619-4786-953A-7ECF42936C87, &access_key, &encryption_key, 
     *                          output_file=/tmp/basket_output.csv);
     */
    
    %local api_url temp_file auth_headers;
    %let api_url = https://api.economy.com/data/v1/orders?id=&basket_id.%str(&)type=baskets;
    %let temp_file = %sysfunc(pathname(work))/basket_output;
    
    %if %upcase(&auth_method.) = HMAC %then %do;
        %setup_hmac_headers(&access_key., &encryption_key., auth_headers);
    %end;
    %else %if %upcase(&auth_method.) = OAUTH %then %do;
        %setup_oauth_headers(&oauth_token., auth_headers);
    %end;
    
    filename output_ref "&temp_file.";
    
    proc http
        url="&api_url."
        method="GET"
        out=output_ref;
        headers
            &auth_headers.
            "Accept" = "*/*";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        %put NOTE: Successfully retrieved basket output for &basket_id..;
        
        %if %length(&output_file.) > 0 %then %do;
            filename copy_out "&output_file.";
            
            data _null_;
                infile output_ref lrecl=32767;
                file copy_out;
                input;
                put _infile_;
            run;
            
            filename copy_out clear;
            %put NOTE: Output saved to &output_file..;
        %end;
        
        %if %index(%upcase(&SYS_PROCHTTP_CONTENT_TYPE.), JSON) > 0 %then %do;
            libname output_lib json fileref=output_ref;
            
            data &output_dataset.;
                set output_lib.root;
            run;
            
            libname output_lib clear;
            %put NOTE: JSON data loaded into dataset &output_dataset..;
        %end;
    %end;
    %else %do;
        %put ERROR: Failed to retrieve basket output for &basket_id.. Status code: &SYS_PROCHTTP_STATUS_CODE.;
    %end;
    
    filename output_ref clear;
%mend retrieve_basket_output;
