#Python script to check emails with mailboxlayer api

import re
import socket
import smtplib
import dns.resolver
import json
import requests
import sys

MAIL_ACCESS_KEY = '<API KEY>'
with open('missing.txt') as emails:
        emaillists = [word.strip() for word in emails]
        for inputAddress in emaillists:
                link = 'http://apilayer.net/api/check?access_key=' + MAIL_ACCESS_KEY + '&email=' + inputAddress + '&smtp=1&format=1'
                response = requests.get(link)
                #print (response.url)
                #print (response.json)
                print (response.text)
                with open('output.txt','a') as log_file:
                        log_file.write(response.text + '\n')
#               if 'str' in inputAddress:
#                       break
