#!/bin/bash

# Envía el error a un XML para que XQuery lo pueda parsear.
# @param_1 => message (Mensaje de error)
function write_error () {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root><error><message>$1</message><code>script_error</code></error></root>" > flights.xml
}

# Llama a la API y guarda lo recibido en los archivos XML
function get_data () {
    curl -s https://airlabs.co/api/v9/airports.xml -d api_key="$AIRLABS_API_KEY" > airports.xml
    curl -s https://airlabs.co/api/v9/countries.xml -d api_key="$AIRLABS_API_KEY" > countries.xml
    curl -s https://airlabs.co/api/v9/flights.xml -d api_key="$AIRLABS_API_KEY" > flights.xml
}

# Si hay algún error con los parsers, envía un mensaje a pantalla y termina el script.
function parser_error () {
    printf "\033[0;31mAn error was encountered. Make sure you have Java and Saxon parser installed.\n\033[0mRun '$0 help' for more information\n"
    exit 2
}

# Crea los XML vacíos. En el caso de que haya un error en los argumentos del script, XQuery no fallará porque ya existen los archivos.
function start_program () {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root></root>" > airports.xml
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root></root>" > countries.xml
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><root></root>" > flights.xml
}

# Función principal. Llama al resto de funciones para generar el reporte.
# @param_1 => qty (cantidad de vuelos para el informe)
# @param_2 => error (1 si hubo algún error anterior, 0 sino)
function run () {
    printf "\033[0;33mDownloading data...\033[0m\n"

    if [ $2 -eq 0 ] # Si no hubo errores...
    then
        get_data
        if [ $? -ne 0 ]
        then
            start_program
            write_error "Data collection failed."
        fi
    fi

    # Las salidas de error de los parsers se envían a /dev/null para no interrumpir el flujo.
    java net.sf.saxon.Query extract_data.xq > flights_data.xml 2> /dev/null
    if [ $? -ne 0 ]
    then
        parser_error
    fi

    java net.sf.saxon.Transform -s:flights_data.xml -xsl:generate_report.xsl qty="$1" -o:report.tex &> /dev/null
    if [ $? -ne 0 ]
    then
        parser_error
    fi

    printf "\033[0;32mReport generated.\033[0m\n"
    exit 0
}

# Función de información. Imprime a pantalla la información acerca del script.
function help () {
    printf "\033[0;33mFlight Report Generator\n"
    printf "\033[0mUsage:\n"
    printf "\033[0;34m     $0 [quantity?] \033[0mDefalult behaviour. Will generate the report. Quantity argument is an optional number greater than zero. If supplied, report will be generated with that amount of flights.\n"
    printf "\033[0;34m     $0 clean \033[0mRemoves all files created by the script, the report included.\n"
    printf "\033[0;34m     $0 help \033[0mThis menu.\n"
    printf "\n"
    printf "\033[0mImportant Information:\n"
    printf "• You must have an environment variable called AIRLABS_API_KEY set with your API key for the service.\nUse \033[0;34m\$> export AIRLABS_API_KEY=\"your_key\"\033[0m\n"
    printf "• In order to obtain the desired result, you must have an internet connection and the following packages installed:\n"
    printf "     • Java\n"
    printf "     • CURL\n"
    printf "     • Saxon Parser\n"
    printf "\n"
    printf "By Axel Preiti, Mariano Agopian, Matias Rinaldo & Alejo Flores Lucey\n"
}

# Función para obtener el estado previo a correr el script. Elimina todo lo creado por él.
function clean () {
    rm airports.xml &> /dev/null
    rm countries.xml &> /dev/null
    rm flights.xml &> /dev/null
    rm flights_data.xml &> /dev/null
    rm report.tex &> /dev/null
    exit 0
}

# Función booleana.
# @param_1 => text (Texto a evaluar)
function is_num () {
    echo $1 | egrep '^[0-9]+$' > /dev/null
}

# Flujo principal del script.
start_program
if [ $# -gt 1 ] # Si se recibió más de un argumento...
then
    write_error "Too many arguments."
    run -1 1
elif [ $# -eq 0 ] # Si no se reciben argumentos, significa que quiero todos los vuelos en el reporte.
then
    run -1 0
else # Este caso debe ser que hay un solo argumento.
    if [ $1 = "help" ] # Si el argumento es "help", llamo a la función.
    then
        help
    elif [ $1 = "clean" ] # Si el argumento es "clean", llamo a la función.
    then
        clean
    elif is_num $1; # Si el argumento es un número...
    then
        if [ $1 -ge 0 ] # Si el argumento es mayor que 0, llamo a los parsers con esa información.
        then
            run $1 0
        else # Sino, el argumento es menor o igual que 0 => envío un error.
            write_error "Argument must be greater or equal than zero."
            run -1 1
        fi
    else # Si no es un número ni palabra reservada, no puedo resolver qué significa => envío un error.
        write_error "Argument supplied cannot be resolved."
        run -1 1
    fi
fi
