#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function checkPort {
    changePort=true
    port=$1
    #netstat -ntpl | grep :${params[dockerHttpPort]} -q
    docker ps -a | grep "0.0.0.0:$port->"
    result=$?
    if [ $result -eq 0 ]
    then 
        echo -e "${RED}Puerto $port ocupado${NC}"
        newPort=$((port+1))
        checkPort $newPort
    else
        echo -e "${GREEN}Puerto $port libre${NC}"
    fi
}

if [ -z "$1" ]
then
    echo -e -e "${RED}Hay que especificar un directorio de destino${NC}"
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
echo -e "${GREEN}Nombre del proyecto (Solo letras y/o números. ${BLUE}Por defecto \"$propossedProyectName\"${GREEN}): ${NC}"
read params[proyectName]
if [ -z "${params[proyectName]}" ]
then
    params[proyectName]="$propossedProyectName"
fi

params[proyectNameToLowwer]="${params[proyectName],,}"
echo -e "${GREEN}Nombre de la imagen de docker a usar (${BLUE}por defecto 'irontec/debian:jessieInit'${GREEN}): ${NC}"
read params[dockerImage]
if [ -z "${params[dockerImage]}" ]
then
    params[dockerImage]='irontec/debian:jessieInit'
fi
params[dockerImage]="${params[dockerImage]//\//\\\/}"
echo -e "${GREEN}Puerto HTTP a mapear (${BLUE}por defecto el 8080${GREEN}): ${NC}"
read params[dockerHttpPort]
if [ -z "${params[dockerHttpPort]}" ]
then
    params[dockerHttpPort]="8080"
fi
checkPort ${params[dockerHttpPort]}
params[dockerHttpPort]=$port
echo -e "${YELLOW}se usará el puerto ${params[dockerHttpPort]}${NC}"

echo -e "${GREEN}Puerto HTTPS a mapear (${BLUE}por defecto el 9443${GREEN}): ${NC}"
read params[dockerHttpsPort]
if [ -z "${params[dockerHttpsPort]}" ]
then
    params[dockerHttpsPort]="9443"
fi
checkPort ${params[dockerHttpsPort]}
params[dockerHttpsPort]=$port
echo -e "${YELLOW}se usará el puerto ${params[dockerHttpsPort]}${NC}"
echo -e "${GREEN}Carpeta de la librería de Klear (${BLUE}por defecto en '/opt/klear-development'${GREEN}): ${NC}"
read params[klearLibraryFolder]
if [ -z "${params[klearLibraryFolder]}" ]
then
    params[klearLibraryFolder]="/opt/klear-development"
fi
params[klearLibraryFolder]="${params[klearLibraryFolder]//\//\\\/}"
echo -e "${GREEN}Nombre de la base de datos (${BLUE}por defecto el nombre del proyecto${GREEN}): ${NC}"
read params[dataBaseName]
if [ -z "${params[dataBaseName]}" ]
then
    params[dataBaseName]=${params[proyectNameToLowwer]}
fi
echo -e "${GREEN}Usuario de la base de datos (${BLUE}por defecto root${GREEN}): ${NC}"
read params[dataBaseUser]
if [ -z "${params[dataBaseUser]}" ]
then
    params[dataBaseUser]="root"
fi
echo -e "${YELLOW}Contraseña de la base de datos: ${NC}"
read -s params[dataBasePassword]
if [ -z "${params[dataBasePassword]}" ]
then
    echo -e "${RED}Debes especificar una contraseña para la base de datos${NC}"
    exit 2
fi

params[dImageLine]="d.image = \"${params[dockerImage]}\""
params[dBuildDirLine]='d.build_dir = "\.\/"'
uid=$(id -u)
params[uid]=$uid

if [ "$uid" != "1000" ]; then
   echo -e "${YELLOW}El uid del usuario es $uid por lo que no se puede usar la imagen que se encuentra en el servidor"
   echo -e "Hay que construir una imagen nueva a partir del Dockerfile"
   echo -e "Al hacer 'vagrant up' se creará una imagen nueva${NC}"
   params[dImageLine]="#${params[dImageLine]}"
else
    params[dBuildDirLine]="#${params[dBuildDirLine]}"
fi

saveIFS=$IFS
IFS=$(echo -e -en "\n\b")
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


echo -e "${YELLOW}Elige el rol que quieres configurar: ${NC}"
for file in $(find "$dir/Provision/roles/"*)
do
    task=`basename $file`
    echo -e "${BLUE}    $task${NC}"
done
echo -e "${YELLOW}Task número [${BLUE}por defecto 001${YELLOW}]: ${NC}"
read taskNumber
if [ -z "${taskNumber}" ]
then
    taskNumber="001"
fi
taskFile=$(find "$dir/Provision/roles/$taskNumber-"*)
taskName=`basename $taskFile`
echo "    - include: roles/$taskName" >> "$dir/Provision/playbook.yml"

IFS=$saveIFS

echo -e "${GREEN}Se ha configurado correctamente el proyecto para usar con Vagrant, Ansible y Docker."
echo -e "Ejecuta 'vagrant up' para arrancar el contenedor${NC}"

exit 0