#!/bin/bash

declare -A params

read -p "Nombre del proyecto (Solo letras y/o números): " params[proyectName]
if [ -z "${params[proyectName]}" ]
then
    echo "Debes especificar un nombre para el proyecto"
    exit 1
fi
read -p "Nombre de la imagen de docker a usar (por defecto 'irontec/debian:init'): " params[dockerImage]
if [ -z "${params[dockerImage]}" ]
then
    params[dockerImage]='irontec/debian:init'
fi
params[dockerImage]="${params[dockerImage]//\//\\\/.}"

read -p "Puerto HTTP a mapear (por defecto el 8080): " params[dockerHttpPort]
if [ -z "${params[dockerHttpPort]}" ]
then
    params[dockerHttpPort]="8080"
fi
read -p "Puerto HTTPS a mapear (por defecto el 9443): " params[dockerHttpsPort]
if [ -z "${params[dockerHttpsPort]}" ]
then
    params[dockerHttpsPort]="9443"
fi
read -p "Carpeta de la librería de Klear (por defecto en '/opt/klear-development'): " params[klearLibraryFolder]
if [ -z "${params[klearLibraryFolder]}" ]
then
    params[klearLibraryFolder]="/opt/klear-development"
fi
params[klearLibraryFolder]="${params[klearLibraryFolder]//\//\\\/}"
read -p "Nombre de la base de datos (por defecto el nombre del proyecto): " params[dataBaseName]
if [ -z "${params[dataBaseName]}" ]
then
    params[dataBaseName]=${params[dataBaseName]}
fi
read -p "Usuario de la base de datos (por defecto root): " params[dataBaseUser]
if [ -z "${params[dataBaseUser]}" ]
then
    params[dataBaseUser]="root"
fi
echo "Contraseña de la base de datos: "
read -s params[dataBasePassword]
if [ -z "${params[dataBasePassword]}" ]
then
    echo "Debes especificar una contraseña para la base de datos"
    exit 2
fi

for file in $(find * -not -name "start.sh" -not -name "README.md")
do
    for i in "${!params[@]}"
    do
        if [ ! -d "$file" ]
        then
            regex="s/{{$i}}/${params[$i]}/g"
            sed -i "$regex" $file
        fi
    done
done

mv Vagrantfile.template Vagrantfile

exit 0