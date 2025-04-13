import asyncio
from .bases import RequestsManager
from tqdm import tqdm
import pandas as pd
class MercadoLibre(RequestsManager):
    """
    Mercado Libre API client
    """

    def __init__(self, headers=None, queries = {}, session = None, requests_per_minute=1000, requires_proxies=False):
        super().__init__(headers, queries, session, requests_per_minute, requires_proxies)
        self.base_url = "https://listado.mercadolibre.com.ar/"
        self.from_url = "Desde_"
        self.url_end = "_NoIndex_True"
        
    async def perform_scrape(self):
        for key,value in self.queries.items():
            for i in range(0,value*50,50):
                url = self.base_url + key + self.from_url + str(i) + self.url_end
                task = asyncio.create_task(self.fetch_html(url))
                self.tasks.append(task)
        results = []
        for result in tqdm(asyncio.as_completed(self.tasks), total=len(self.tasks)):
            soup = await result
            #soup = BeautifulSoup(res.text, 'html.parser')
            for li in soup.find_all("li", {"class": "ui-search-layout__item"}):
                url = li.find("a").attrs["href"].split("#")[0]
                if "mclics" in url: #ads that are not from the search
                    continue
                if "/p/" in url:
                    ml_id = url.split("/p/")[-1]
                else:
                    ml_id = url.split("/")[3]
                    ml_id = ml_id.split("-")
                    ml_id = "".join(ml_id[0:2])
                title = li.find("a").text
                price = li.find("span", {"class": "andes-money-amount__fraction"} ).text.replace(".","")
                price = float(price.replace(",", "."))
                results.append({
                    "title": title,
                    "price": price,
                    "ml_id": ml_id,
                    "url": url
                })
        self.data = pd.DataFrame(results)
        return self.data