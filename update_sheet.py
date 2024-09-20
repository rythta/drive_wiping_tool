import sys
import httplib2
import os

from apiclient import discovery
from google.oauth2 import service_account

try:
    scopes = ["https://www.googleapis.com/auth/drive", "https://www.googleapis.com/auth/drive.file", "https://www.googleapis.com/auth/spreadsheets"]
    secret_file = os.path.join(os.getcwd(), 'client_secret.json')

    credentials = service_account.Credentials.from_service_account_file(secret_file, scopes=scopes)
    service = discovery.build('sheets', 'v4', credentials=credentials)
    
    SAMPLE_SPREADSHEET_ID = sys.argv[1]
    COLS=''.join(sys.argv[2:]).split(';')
    SAMPLE_RANGE_NAME = COLS[0]+'!A:A'

    Body={'values':[COLS[1:]],'majorDimension':'ROWS'}

    service.spreadsheets().values().append(spreadsheetId=SAMPLE_SPREADSHEET_ID,range=SAMPLE_RANGE_NAME,valueInputOption='RAW',body
=Body).execute()

except OSError as e:
    print(e)

