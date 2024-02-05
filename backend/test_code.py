import pytest
from .lambda_code import index


event = {
    "requestContext": {
        "identity": {
            "sourceIp": "192.168.70.150"
        }
    }
}

context = ""

def test_dbname():
   assert index.table_name == "resume_visitor" 
   
def test_lamba_return_success():
    result = index.lambda_handler(event, context)
    print("Stattus code:")
    assert result['statusCode'] == 200   
    assert type(result) == dict
    assert  "headers" in result
    assert "body" in result 
    

def test_lambda_return_error():
    result = index.lambda_handler({}, context)
    assert result['statusCode'] == 500
    assert result['body'] == "Internal Server Error"    
