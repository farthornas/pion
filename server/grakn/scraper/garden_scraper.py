from bs4 import BeautifulSoup
import requests
import json

# spoof to be allowed access to site
USR = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36'
URL_norske = "http://norskeplanter.no/nedlasting-av-produktark/planteliste/"
URL_gardenOrg = "https://garden.org/"
PLNTS_NOR = "norwegian_plants.json"
PLNTS = "plants.json"

#'div', class_="wc-product__part wc-product__description hide-in-grid show-in-list"

def norske_planter(url):
    plants = {}
    page = requests.get(url)
    soup = BeautifulSoup(page.content, 'html.parser')
    results = soup.find(id="site-content")
    plant_elements = results.find_all('div', class_="wc-product-inner")
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
    #plants = json.JSONEncoder().encode(plants)
    with open(PLNTS_NOR, "w") as file:
        print("Writing to: " + PLNTS_NOR)
        json.dump(plants, file)

def gardenOrg_search(plant_name):
    #Finds all plants associated with the plant name and returns a list

    #plants = {}
    #plants_nor = None
    #p = {}
    query = URL_gardenOrg + "search/index.php?q=" + plant_name.replace(" ", "+")
    page = requests.get(query, headers={'User-agent':USR})
    soup = BeautifulSoup(page.content, "html.parser")
    plant_list = soup.tbody.find_all('a')
    sub_species = []
    for plant in plant_list:
        if "img alt" in str(plant):
            continue
        print(plant)
        plant = str(plant).split("\"")
        link, plant = plant[1], plant[1].split("/")[4].replace("-", " ")
        sub_species.append({plant:link})
    with open(PLNTS_NOR, 'r') as file:
        plants_nor = json.load(file)
    #p["sub_species"] = sub_species
    return sub_species
    #p["norwegian_name"] = plants_nor[plant_name]["local_name"]
    #plants[plant_name] = p
    #plants[plant_name] =
    #with open(PLNTS, 'w') as file:
        #json.dump(plants, file)

def growth_data(link):
    """Takes a link from the associated with the specific plant from the
    Garden org website and compiles the growth data into a list"""
    

    return 0

    #plant_list = soup.tbody.find_all(re.compile("\d/([^/]*)"))

#norske_planter(URL_norske)
q_return = gardenOrg_search("Achillea millefolium")
#gardenOrg_search("Verbascum nigrum")
print(q_return)
