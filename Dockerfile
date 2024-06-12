FROM node:19-alpine3.15

WORKDIR /REDDIT-CLONE

COPY . /REDDIT-CLONE
RUN npm install 

EXPOSE 3000
CMD ["npm","run","dev"]
