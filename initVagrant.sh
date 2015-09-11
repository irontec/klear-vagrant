#!/bin/bash

function checkPort {
    changePort=true
    port=$1
    #netstat -ntpl | grep :${params[dockerHttpPort]} -q
    docker ps -a | grep "0.0.0.0:$port->"
    result=$?
    if [ $result -eq 0 ]
    then 
        echo "Puerto $port ocupado"
        newPort=$((port+1))
        checkPort $newPort
    else
        echo "Puerto $port libre"
    fi
}

if [ -z "$1" ]
then
    echo "Hay que especificar un directorio de destino"
    exit 1
fi 

if [[ "$1" = /* ]]
then
    dir=$1
else
    dir=`pwd`/$1
fi

dir=${dir%.}
dir=${dir%/}
dir=${dir// /\ }

dirBasename=`basename "$dir"`

if [ -L $0 ]
then
    scriptFile=$(readlink -f "$0")
else
    scriptFile=$0
fi

if [[ "$scriptFile" = /* ]]
then
    scriptDir=`dirname $scriptFile`
else
    scriptDir=`pwd`/`dirname $scriptFile`
fi
scriptDir=${scriptDir// /\ }

cp -r "$scriptDir/"* "$dir/"
rm "$dir/initVagrant.sh"
declare -A params

lowerDirBasename=${dirBasename,,}
propossedProyectName=${lowerDirBasename// /}
read -p "Nombre del proyecto (Solo letras y/o números. Por defecto \"$propossedProyectName\"): " params[proyectName]
if [ -z "${params[proyectName]}" ]
then
    params[proyectName]="$propossedProyectName"
fi

params[proyectNameToLowwer]="${params[proyectName],,}"

read -p "Nombre de la imagen de docker a usar (por defecto 'irontec/debian:jessieInit'): " params[dockerImage]
if [ -z "${params[dockerImage]}" ]
then
    params[dockerImage]='irontec/debian:jessieInit'
fi
params[dockerImage]="${params[dockerImage]//\//\\\/}"

read -p "Puerto HTTP a mapear (por defecto el 8080): " params[dockerHttpPort]
if [ -z "${params[dockerHttpPort]}" ]
then
    params[dockerHttpPort]="8080"
fi
checkPort ${params[dockerHttpPort]}
params[dockerHttpPort]=$port
echo "se usará el puerto ${params[dockerHttpPort]}"


read -p "Puerto HTTPS a mapear (por defecto el 9443): " params[dockerHttpsPort]
if [ -z "${params[dockerHttpsPort]}" ]
then
    params[dockerHttpsPort]="9443"
fi
checkPort ${params[dockerHttpsPort]}
params[dockerHttpsPort]=$port
echo "se usará el puerto ${params[dockerHttpsPort]}"

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

params[dImageLine]="d.image = \"${params[dockerImage]}\""
params[dBuildDirLine]='d.build_dir = "\.\/"'
uid=$(id -u)
params[uid]=$uid

if [ "$uid" != "1000" ]; then
   echo "El uid del usuario es $uid por lo que no se puede usar la imagen que se encuentra en el servidor"
   echo "Hay que construir una imagen nueva a partir del Dockerfile"
   echo "Al hacer 'vagrant up' se creará una imagen nueva"
   params[dImageLine]="#${params[dImageLine]}"
else
    params[dBuildDirLine]="#${params[dBuildDirLine]}"
fi

saveIFS=$IFS
IFS=$(echo -en "\n\b")
for file in $(find "$dir/"* -not -name "start.sh" -not -name "README.md")
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
IFS=$saveIFS
exit 0