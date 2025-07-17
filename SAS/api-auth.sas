/*
 * Data Buffet API Authentication Functions
 * SAS Implementation for HMAC and OAuth 2.0 Authentication
 * 
 * This file provides authentication macros for the Data Buffet API
 * supporting both HMAC-SHA256 signature generation and OAuth 2.0 token-based authentication.
 */

%macro create_hmac_signature(access_key, encryption_key, timestamp, signature_var);
    /*
     * Creates HMAC-SHA256 signature for Data Buffet API authentication
     * 
     * Parameters:
     *   access_key: Your Data Buffet API access key (36-character hex string)
     *   encryption_key: Your Data Buffet API encryption key (36-character hex string)  
     *   timestamp: UTC timestamp in format YYYY-MM-DDTHH:MM:SSZ
     *   signature_var: Name of macro variable to store the resulting signature
     *
     * Example:
     *   %create_hmac_signature(&access_key, &encryption_key, &timestamp, signature);
     */
    
    %local hash_input temp_file;
    
    %let hash_input = &access_key.&timestamp.;
    %let temp_file = %sysfunc(pathname(work))/hmac_temp.txt;
    
    data _null_;
        length hash_input $200 encryption_key $36 signature $64;
        hash_input = "&hash_input.";
        encryption_key = "&encryption_key.";
        
        signature = put(sha256(hash_input, encryption_key), hex64.);
        signature = upcase(signature);
        
        call symputx("&signature_var.", signature);
    run;
%mend create_hmac_signature;

%macro get_oauth_token(access_key, encryption_key, token_var, token_type_var=, expires_in_var=);
    /*
     * Obtains OAuth 2.0 token from Data Buffet API
     * 
     * Parameters:
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   token_var: Name of macro variable to store the access token
     *   token_type_var: Optional - name of macro variable to store token type (default: bearer)
     *   expires_in_var: Optional - name of macro variable to store expiration time (default: 3600)
     *
     * Example:
     *   %get_oauth_token(&access_key, &encryption_key, oauth_token);
     */
    
    %local oauth_url oauth_response temp_file;
    %let oauth_url = https://api.economy.com/data/v1/oauth2/token;
    %let temp_file = %sysfunc(pathname(work))/oauth_response.json;
    
    filename oauth_out "&temp_file.";
    
    proc http
        url="&oauth_url."
        method="POST"
        out=oauth_out;
        headers
            "Content-Type" = "application/x-www-form-urlencoded";
        data "client_id=&access_key.&client_secret=&encryption_key.&grant_type=client_credentials";
    run;
    
    %if &SYS_PROCHTTP_STATUS_CODE. = 200 %then %do;
        libname oauth_lib json fileref=oauth_out;
        
        data _null_;
            set oauth_lib.root;
            call symputx("&token_var.", access_token);
            %if %length(&token_type_var.) > 0 %then %do;
                call symputx("&token_type_var.", token_type);
            %end;
            %if %length(&expires_in_var.) > 0 %then %do;
                call symputx("&expires_in_var.", expires_in);
            %end;
        run;
        
        libname oauth_lib clear;
    %end;
    %else %do;
        %put ERROR: OAuth token request failed with status code &SYS_PROCHTTP_STATUS_CODE.;
        %let &token_var. = ;
    %end;
    
    filename oauth_out clear;
%mend get_oauth_token;

%macro format_utc_timestamp(timestamp_var);
    /*
     * Formats current datetime as UTC timestamp for API requests
     * 
     * Parameters:
     *   timestamp_var: Name of macro variable to store the formatted timestamp
     *
     * Example:
     *   %format_utc_timestamp(current_timestamp);
     */
    
    data _null_;
        utc_time = datetime();
        formatted_time = put(utc_time, e8601dt19.) || "Z";
        call symputx("&timestamp_var.", formatted_time);
    run;
%mend format_utc_timestamp;

%macro setup_hmac_headers(access_key, encryption_key, headers_var);
    /*
     * Sets up HTTP headers for HMAC authentication
     * 
     * Parameters:
     *   access_key: Your Data Buffet API access key
     *   encryption_key: Your Data Buffet API encryption key
     *   headers_var: Name of macro variable to store header string for PROC HTTP
     *
     * Example:
     *   %setup_hmac_headers(&access_key, &encryption_key, auth_headers);
     */
    
    %local timestamp signature;
    
    %format_utc_timestamp(timestamp);
    %create_hmac_signature(&access_key., &encryption_key., &timestamp., signature);
    
    %let &headers_var. = "AccessKeyId" = "&access_key." "Signature" = "&signature." "TimeStamp" = "&timestamp.";
%mend setup_hmac_headers;

%macro setup_oauth_headers(oauth_token, headers_var);
    /*
     * Sets up HTTP headers for OAuth authentication
     * 
     * Parameters:
     *   oauth_token: OAuth access token obtained from get_oauth_token
     *   headers_var: Name of macro variable to store header string for PROC HTTP
     *
     * Example:
     *   %setup_oauth_headers(&oauth_token, auth_headers);
     */
    
    %let &headers_var. = "Authorization" = "Bearer &oauth_token.";
%mend setup_oauth_headers;
