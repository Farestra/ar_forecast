#!/usr/bin/env bash

##############################################################################################################
#Author: Fausto Renzo Stradiotto <stradiotto.fausto@gmail.com>
#Date: 2023/09/06
#Requires: curl [https://curl.se/], grep [https://www.gnu.org/software/grep], jq [https://jqlang.github.io/jq/]
##############################################################################################################


# Obtener el token 
TOKEN=$(curl -s https://www.smn.gob.ar/ | grep -oP "(?<='token',[[:space:]]').*(?=')")

# Verificar si el token es nulo o no está asignado
if [ -z "$TOKEN" ]; 
then
    echo "Error: No hay token"   
else
    echo "Token Obtenido con éxito, verificando archivo de datos..."
    # Verificar si existe un archivo de datos en el directorio local
    if [ -f "./data.json" ]; then
        # Si existe eliminarlo para escribirlo con la información actualizada
        echo "Archivo \"./data.json\" encontrado, borrando..."
        rm -rf ./data.json
    fi
    # Con el token obtener los datos, redirigir la salida a jq para formatear y generar un archivo json con los datos.
    curl -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" https://ws1.smn.gob.ar/v1/weather/location/zoom/2 | jq . >> data.json
fi
