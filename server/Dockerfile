# Image de production du serveur Lango (Node.js 26 LTS)
FROM node:26-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
COPY test ./test
RUN npm run build

FROM node:26-slim
WORKDIR /app
# NODE_ENV se règle dans les variables d'environnement de l'hébergeur :
# laisser vide pour la version de test, 'production' pour le lancement.
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/src/main.js"]
