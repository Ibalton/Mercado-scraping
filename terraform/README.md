# Terraform

Para armar esto hay que cargar la imagen antes de aplicar el resto

terraform apply -target="module.ecr"



# TODO:

armar 

./push.sh

terraform apply

La region y el url te lo manda el output de terraform apply

En mi caso sale esto ->

"992382783225.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper:latest"

Hay que modificar el string para generar el comando de abajo

```aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 992382783225.dkr.ecr.us-east-1.amazonaws.com```

Cuando tenemos eso podemos generar la imagen de docker y pushearla

```bash
docker build -t backend ./backend
docker tag backend:latest "992382783225.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper:latest"
docker push "992382783225.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper:latest"
```

