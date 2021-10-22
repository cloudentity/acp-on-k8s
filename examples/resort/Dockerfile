FROM apisguru/graphql-faker:v2.0.0-rc.25

COPY resort.graphql resort.graphql

ENTRYPOINT [ "node", "/usr/local/bin/graphql-faker", "./resort.graphql" ]

EXPOSE 9002
