#!/usr/bin/env python3

import sys
import os
try:
    import dbapi
except Exception as ex:
    print(ex)
    print('Make sure dbapi.py is downloaded to the same directory as this program, and run again')
    print('Get it here: https://github.com/moodysanalytics/databuffet-api-codesamples/blob/master/Python/dbapi.py')
    sys.exit()
import pandas as pd
import numpy as np
from datetime import datetime

def prompt(prompt_text: str):
    ret = None
    while ret is None:
        ret = input(f'{prompt_text} : ').strip()
    return ret

print('\nData Buffet API - Vintage Filter Basket Example')
print('Get your API keys here: https://economy.com/myeconomy/api-key-info\n')

access_key = prompt('Please enter your access key')
encryption_key = prompt('Please enter your encryption key')

api = dbapi.DataBuffetAPI(access_key, encryption_key)

print('\n=== Example 1: Basket with Vintage Filter ===')
basket_name = "Vintage_Basket_" + datetime.now().strftime('%Y_%m_%d_%H_%M_%S_%f')
vintage_value = "2022Q1"  # Example vintage in YYYYQ# format
vintage_version = 1

try:
    basket = api.create_basket(
        title=basket_name,
        filetype=dbapi.DBFileType.Excel,
        decimals=2,
        start="2020-01-01",
        end="2022-12-31",
        frequency=dbapi.BasketFrequency.Monthly,
        vintage=vintage_value,
        vintage_version=vintage_version
    )
    
    basket_id = basket['basketId']
    print(f'Created basket: {basket_name}')
    print(f'Basket ID: {basket_id}')
    print(f'Using vintage: {vintage_value}, version: {vintage_version}')
    print(f'Basket URL: https://www.economy.com/databuffet/preview/basket/{basket_id}')
    
    series_list = ["USCB.HOUS_HN", "USCB.HOUS_HVS"]
    api.add_series_to_basket(basket_id, series_list)
    print(f'Added series to basket: {series_list}')
    
    order_result = api.run_basket(basket_id)
    print(f"Order ID: {order_result['orderId']}")
    
    print('Waiting for order to complete...')
    api.wait_for_order(order_result)
    
    basket_data = api.get_basket_output_file(basket_id, saveto=f'{basket_name}.xlsx')
    print(f'Basket data file written to {os.getcwd()}/{basket_name}.xlsx')
    
except Exception as e:
    print(f'Error in Example 1: {e}')

print('\n=== Example 2: Different Vintage Formats ===')

vintage_formats = [
    ("2021", "YYYY format"),
    ("202112", "YYYYMM format"), 
    ("2021Q4", "YYYYQ# format")
]

for vintage_val, description in vintage_formats:
    try:
        basket_name_fmt = f"Vintage_{vintage_val}_" + datetime.now().strftime('%H_%M_%S')
        
        basket = api.create_basket(
            title=basket_name_fmt,
            filetype=dbapi.DBFileType.JSON,
            vintage=vintage_val,
            vintage_version=1
        )
        
        print(f'Created basket with {description}: {vintage_val}')
        print(f'Basket ID: {basket["basketId"]}')
        
    except Exception as e:
        print(f'Error creating basket with vintage {vintage_val}: {e}')

print('\n=== Example 3: Edit Basket Settings with Vintage ===')

try:
    basic_basket = api.create_basket(
        title="Basic_Basket_" + datetime.now().strftime('%H_%M_%S'),
        filetype=dbapi.DBFileType.CSV
    )
    
    basket_id = basic_basket['basketId']
    print(f'Created basic basket: {basket_id}')
    
    updated_basket = api.edit_basket_settings(
        basket_id=basket_id,
        vintage="2023Q2",
        vintage_version=2,
        decimals=3,
        frequency=dbapi.BasketFrequency.Quarterly
    )
    
    print('Updated basket settings with vintage: 2023Q2, version: 2')
    print(f'Updated basket response: {updated_basket}')
    
except Exception as e:
    print(f'Error in Example 3: {e}')

print('\n=== Vintage Filter Examples Complete ===')
print('The vintage parameter supports the following formats:')
print('- YYYY (e.g., "2023")')
print('- YYYYMM (e.g., "202301")')
print('- YYYYQ# (e.g., "2023Q1")')
print('The vintage parameter is automatically converted to uppercase and whitespace is stripped.')
