####################
# Parse ATC codes from https://atcddd.fhi.no/atc_ddd_index
####################


# Load packages
import numpy as np
import pandas as pd
import datetime
from bs4 import BeautifulSoup
import urllib.request
import re
import time


# Request parameters
endpoint = "https://atcddd.fhi.no/atc_ddd_index"
para1 = "/?code="
para2 = "&showdescription=no"


####################
# functions
####################

# extract the value between '=' and '&' in href
def extractValue(s):
    return s.split('=')[1].split('&')[0]


def extractTable(soup):
  # Locate the table
  if soup.find('div', {'id': 'content'}).find('table'):
    table = soup.find('div', {'id': 'content'}).find('table')
    
    # Extract column headers
    headers = [header.get_text(strip=True) for header in table.find_all('tr')[0].find_all('td')]
    
    # Extract row data
    rows = []
    for tr in table.find_all('tr')[1:]:  # Skip header row
        cols = [td.get_text(strip=True) for td in tr.find_all('td')]
        rows.append(cols)
  
    # Create a dataframe
    df_atc_ddd = pd.DataFrame(rows, columns=headers)
    return df_atc_ddd


# request the website
def parseATC(atc_as_para):
  # Parse HTML content
  time.sleep(10) # wait 10 seconds to avoid overloading the server
  url = endpoint + para1 + atc_as_para + para2
  html_content = urllib.request.urlopen(url).read()
  return BeautifulSoup(html_content, "html.parser")


# extract data from href elements
def extractATC(soup):
  # Find all "a" elements in DOM with "code" inside
  codes = soup.find_all(href=re.compile("code"))
  
  # Extract the data
  atc_names = [a.text for a in codes]
  href_string = [str(a.attrs) for a in codes]
  
  # Create local data frame
  data = {"atc_name": atc_names, "href": href_string}
  df_data = pd.DataFrame(data)
  
  # Extract atc code from href and delete href column
  df_data['atc_code'] = df_data['href'].apply(lambda x: extractValue(x))
  del df_data['href']
  df_data = df_data[df_data['atc_name']!='Show text from Guidelines']
  
  # calculate atc-level (length of atc code)
  df_data['level'] = df_data['atc_code'].apply(lambda x: len(x))
  print(datetime.datetime.now()) # just showing script is running
  return df_data


####################
# initial objects and main level
####################
df_combined = df = pd.DataFrame()
df_combined = df = extractATC(parseATC(""))
df_atc_ddd = pd.DataFrame()


####################
# scrape the atc index (ca. 5 minutes without time.sleep)
####################
level_iterator = np.array([1,3,4,5])

for li in level_iterator:
  print("level: "+str(li))
  df = df_combined[df_combined.level==li]
  
  for row in df.itertuples():
    html_soup = parseATC(row.atc_code)
    df_data = extractATC(html_soup) # global data frame
    df_combined = pd.concat([df_combined, df_data], ignore_index=True)
    # second df with table data
    if len(row.atc_code) == 5:
      df_atc_ddd = pd.concat([df_atc_ddd, extractTable(html_soup)], ignore_index=True)
    
  # drop duplicates in ATC list
  df_combined = df_combined.drop_duplicates()


####################
# finish
####################
df_combined = df_combined.sort_values('atc_code')
df_combined.to_csv('atc_list.csv', index=False, sep='|')

# fill missing values for DDD  
df_atc_ddd.replace("", pd.NA, inplace=True)
df_atc_ddd[['ATC code', 'Name']] = df_atc_ddd[['ATC code', 'Name']].ffill()
df_atc_ddd = df_atc_ddd[df_atc_ddd['DDD'].notna()]
df_atc_ddd.to_csv('atc_ddd.csv', index=False, sep='|')
