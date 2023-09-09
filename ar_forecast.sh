#!/usr/bin/env bash

# ar_forecast.sh
# Author: Fausto Renzo Stradiotto Amico (Farestra) <stradiotto.fausto@gmail.com>
# Date: 2023-09-09
# Description: El script utiliza curl para obtener datos del Servicio Meteorológico Nacional Argentino,
#   por consola, sin interfaz web, y los almacena localmente.
# Requires: {
# curl [https://curl.se/], 
# grep [https://www.gnu.org/software/grep], 
# jq [https://jqlang.github.io/jq/],
# whiptail [https://pagure.io/newt],
# cut [https://www.maizure.org/projects/decoded-gnu-coreutils/cut.html]
# }
# Notes: for whiptail usage RTFM.
# Licence: none.

# Exports
export TERM=ansi # para evitar errores con whiptail

# Variables
UBICATION=""
UBICATIONENCODE=""
CONNECTION=""
TOKEN=""
UBICATIONID=""
backtitle="AR_forecast"
declare -A locations=()

# Funciones
function checkAll {
    # Verificar que todos los comandos necesarios estén disponibles

    hash whiptail 2>/dev/null && { local swhiptail=1; } || { local swhiptail=0; }
    hash curl 2>/dev/null && { local scurl=1; } || { local scurl=0; }
    hash grep 2>/dev/null && { local sgrep=1; } || { local sgrep=0; }
    hash jq 2>/dev/null && { local sjq=1; } || { local sjq=0; }
    hash cut 2>/dev/null && { local cut=1; } || { local cut=0; }
    if [[ $swhiptail = 1 && $scurl = 1 && $sgrep = 1 && $sjq = 1 && $cut = 1 ]]; then
        printf "Todos los comandos necesarios están disponibles\n"
        getToken
    else 
        printf "Faltan comandos necesarios para ejecutar el script\n"
        exit 1
    fi
}

function uriEncode {
    # Codifica una cadena de texto para conformar una URI en la petición GET

    while [ -z "$UBICATION" ]; do
        UBICATION=$(
            whiptail --inputbox "Indique una ubicación" \
            --title "Codificar Ubicación" \
            8 39 \
            3>&1 1>&2 2>&3
            );
        UBICATIONENCODE=$(printf %s "$UBICATION" | jq -sRr @uri)
    done
    whiptail --title "Ubicación codificada" --backtitle $backtitle --msgbox "$UBICATIONENCODE" 8 78
}

function checkConnection {
    # Verifica la conextividad a internet mediante el Network Wrapper

    if : >/dev/tcp/8.8.8.8/53; then
        CONNECTION='Online'
    else
        CONNECTION='Offline'
    fi
    whiptail --title "Estado de Conexión" --backtitle $backtitle --msgbox "$CONNECTION" 8 78
}

function getToken {

    # Extrae el token del código fuente de la web y lo almacena en la variable

    TOKEN=$(curl -s https://www.smn.gob.ar/ | grep -oP "(?<='token',[[:space:]]').*(?=')")
    whiptail --title "Token Obtenido" --backtitle $backtitle --msgbox "$TOKEN" 8 78
}

function getGeneralData {
    # Obtiene datos generales

    if [ -z "$TOKEN" ]; then
        whiptail --title "Error" --msgbox "Token Vacío" 8 78
    else
        curl -s -H 'Accept: application/json' \
        -H "Authorization: JWT ${TOKEN}" \
        https://ws1.smn.gob.ar/v1/weather/location/zoom/2 | jq . >> data.json
        whiptail --title "Éxito" --backtitle $backtitle --msgbox --scrolltext "$(head data.json)" 16 78
    fi
}

function requestLocationId {
    # Obtiene un array de ubicaciones coincidentes en base a la cadena de ubicación obtenida

    response=$(curl -s -H 'Accept: application/json, text/javascript, */*; q=0.01'\
    https://ws1.smn.gob.ar/v1/georef/location/search?name="$UBICATIONENCODE")
    if [ -f "./response.json" ]; then
        rm -rf ./response.json
    fi
    echo "$response" >> response.json
    
    cantidad=$(jq '.|length' response.json)

    if [ "$cantidad" -gt 1 ]; then
        for i in $(seq "$(jq '.|length' response.json)"); do \
            j=$((i - 1)); \
            locations[$j]=$(jq ".[$j]" response.json | tr -d '[:space:]\n\[' | cut -d, -f 1,2,3,4);  \
        done

        choices=();
        for key in "${!locations[@]}"; do
            choices+=("$key" "${locations[$key]}");
        done;
        result=$(
            whiptail --title "Seleccione una ubicación" \
                     --menu "Elija una opción" \
                     16 78 9 "${choices[@]}" \
                     3>&1 1>&2 2>&3
                     )
        UBICATIONID=$(echo "${locations[$result]}" | cut -d, -f 1 )
    else
        UBICATIONID=$(echo "$response" | cut -d, -f 1 )
    fi
    whiptail --title "ID de ubicación:" --backtitle $backtitle --msgbox "$UBICATIONID" 8 78
    rm -rf ./response.json
}

function getAll {
    # Obtiene información de todos los endpoints accesibles y los almacena en un directorio
    # esta función crea un directorio en base a la fecha y la hora del sistema,
    # y dentro de él crea un archivo json con el contenido de cada respuesta.

    now=$(date +"%d%m%Y%H%M")
    mkdir "$now"
    {
        curl -s -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" \
        https://ws1.smn.gob.ar/v1/georef/location/"$UBICATIONID" | jq . >> "$now"/georef_loc.json
    } | whiptail --gauge --backtitle $backtitle "Obteniendo: /georef/location/$UBICATIONID ..." 10 70 0
    
    {
        curl -s -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" \
        https://ws1.smn.gob.ar/v1/forecast/location/"$UBICATIONID" | jq . >> "$now"/forecast_loc.json
    } | whiptail --gauge --backtitle $backtitle "Obteniendo: /forecast/location/$UBICATIONID ..." 10 70 20

    {
        curl -s -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" \
        https://ws1.smn.gob.ar/v1/warning/alert/location/"$UBICATIONID" | jq . >> "$now"/alert_loc.json
    } | whiptail --gauge --backtitle $backtitle "Obteniendo: /warning/alert/location/$UBICATIONID ..." 10 70 40

    {
        curl -s -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" \
        https://ws1.smn.gob.ar/v1/warning/shortterm/location/"$UBICATIONID" | jq . >> "$now"/shortterm_loc.json
    } | whiptail --gauge --backtitle $backtitle "Obteniendo: /warning/shortterm/location/$UBICATIONID ..." 10 70 60

    # {
    #     curl -s -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" \
    #     https://ws1.smn.gob.ar/v1/warning/heat/area/"$UBICATIONID" | jq . >> "$now"/heat_area.json
    # } | whiptail --gauge "Obteniendo: /warning/heat/area/$UBICATIONID ..." 10 70 80

    {
        curl -s -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" \
        https://ws1.smn.gob.ar/v1/sun/location/"$UBICATIONID" | jq . >> "$now"/sun_loc.json
    } | whiptail --gauge --backtitle $backtitle "Obteniendo: /sun/location/$UBICATIONID ..." 10 70 75

    {
        curl -s -H 'Accept: application/json' -H "Authorization: JWT ${TOKEN}" \
        https://ws1.smn.gob.ar/v1/weather/location/"$UBICATIONID" | jq . >> "$now"/weather_loc.json
    } | whiptail --gauge --backtitle $backtitle "Obteniendo: /weather/location/$UBICATIONID ..." 10 70 100

    whiptail --title "Completado" --backtitle $backtitle --msgbox "Puede ver los datos en /$now/.." 8 78
}

checkAll
checkConnection
uriEncode
getToken
# getGeneralData
requestLocationId     
getAll
