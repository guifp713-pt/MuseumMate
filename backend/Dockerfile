FROM node:20

WORKDIR /app

# Instalar dependências básicas
RUN apt-get update && apt-get install -y tar

# Copiar script
COPY restore.sh /restore.sh
RUN chmod +x /restore.sh

EXPOSE 1337

CMD ["/restore.sh"]