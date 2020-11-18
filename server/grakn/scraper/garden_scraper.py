from bs4 import BeautifulSoup
import requests
from json import dump

import re

URL_norske = "http://norskeplanter.no/nedlasting-av-produktark/planteliste/"
URL_gardenOrg = "https://garden.org/search/index.php?q="
#'div', class_="wc-product__part wc-product__description hide-in-grid show-in-list"

def norske_planter(url):
    page = requests.get(url)
    soup = BeautifulSoup(page.content, 'html.parser')
    print(soup)
    results = soup.find(id="site-content")
    plant_elements = results.find_all('div', class_="wc-product-inner")
    plants = {}
    for plant in plant_elements:
        plant_info = {}
        if plant.h2.a == None:
            continue
        else:
            latin_name = str(plant.h2.a).split(">")[1].split("<")[0]
        if plant.p.b != None:
            local_name = str(plant.p.b)
        else:
            local_name = str(plant.p)
        plant_info["local_name"] = local_name.split(">")[1].split("<")[0]
        plants[latin_name] = plant_info
    with open("norwegian_plants.json", "w") as file:
        dump(plants, file)

def gardenOrg_search(plant):
    #THis could be part of a for loop so that each search is perfomed separately
    query = URL_gardenOrg + plant
    #print(query)
    user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36' # spoof to be allowed access to site
    page = requests.get(query, headers={'User-agent':user_agent})
    soup = BeautifulSoup(page.content, "html.parser")
    #print(soup.tbody)
    plant_list = soup.tbody.find_all('a')
    for plant in plant_list:
        #if hasattr(plant, "img"):
        #    continue
        if "img alt" in str(plant):
            continue
        plant = str(plant).split("\"")[1].split("/")[4]
        print(plant)

    #plant_list = soup.tbody.find_all(re.compile("\d/([^/]*)"))

#norske_planter(URL_norske)
gardenOrg_search("Achillea+millefolium")
gardenOrg_search("Verbascum nigrum")
