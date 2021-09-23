FROM node:16-alpine
RUN apk add --no-cache git

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app
RUN git clone https://github.com/trevorblades/countries
WORKDIR /usr/src/app/countries
RUN npm install

ENV PORT=80
ENTRYPOINT [ "npm", "start" ]

EXPOSE 80