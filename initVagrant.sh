#!/bin/bash
saveIFS=$IFS
IFS=$(echo -e -en "\n\b")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function checkPort {
    changePort=true
    port=$1
    #netstat -ntpl | grep :${params[dockerHttpPort]} -q
    docker ps -a | grep "0.0.0.0:$port->" -q
    result=$?
    if [ $result -eq 0 ]
    then 
        #echo -e "${RED}Puerto $port ocupado${NC}"
        newPort=$((port+1))
        checkPort $newPort
    #else
        #echo -e "${GREEN}Puerto $port libre${NC}"
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

mkdir "$dir/.initVagrant"
cp -r "$scriptDir/"* "$dir/.initVagrant"
rm "$dir/.initVagrant/initVagrant.sh"

lowerDirBasename=${dirBasename,,}

#Elegir el rol a usar
echo -e "${YELLOW}Elige el rol que quieres configurar: ${NC}"
for file in $(find "$dir/.initVagrant/Provision/roles/"*)
do
    role=`basename $file`
    roleFormatted=${role/#0/ }
    roleFormatted=${roleFormatted/# 0/  }
    roleFormatted=${roleFormatted//-/: }
    roleFormatted=${roleFormatted//_/ }
    roleFormatted=${roleFormatted//.yml/}
    echo -e "${BLUE}    $roleFormatted${NC}"
done
echo -e "${YELLOW}Rol número [por defecto ${BLUE}1${YELLOW}]: ${NC}"
read roleNumber
if [ -z "${roleNumber}" ]
then
    roleNumber="001"
else
	printf -v roleNumber "%03d" $roleNumber
fi

roleFile=$(find "$dir/.initVagrant/Provision/roles/$roleNumber-"*)
roleName=`basename $roleFile`
echo "    - include: roles/$roleName" >> "$dir/.initVagrant/Provision/playbook.yml"

declare -A params

propossedProyectName=${lowerDirBasename// /}
echo -e "${GREEN}Nombre del proyecto (Solo letras y/o números. Por defecto \"${BLUE}$propossedProyectName${GREEN}\"): ${NC}"
read params[proyectName]
if [ -z "${params[proyectName]}" ]
then
    params[proyectName]="$propossedProyectName"
fi
params[proyectNameToLowwer]="${params[proyectName],,}"

echo -e "${GREEN}Nombre de la imagen de docker a usar (por defecto '${BLUE}irontec/debian:jessieInit${GREEN}'): ${NC}"
read params[dockerImage]
if [ -z "${params[dockerImage]}" ]
then
    params[dockerImage]='irontec/debian:jessieInit'
fi
#params[dockerImage]="${params[dockerImage]//\//\\/}"

###Puertos a mapear###
params[dockerSshPort]="2200"
checkPort ${params[dockerSshPort]}
params[dockerSshPort]=$port
echo -e "${YELLOW}se mapeará el puerto ${params[dockerSshPort]} local con el puerto 22 del contenedor${NC}"
dockerPorts="[\"${params[dockerSshPort]}:22\""

grep -iq webserver ${roleFile}
if [ "$?" == "0" ]
then  
	params[dockerHttpPort]="8080"
	checkPort ${params[dockerHttpPort]}
	params[dockerHttpPort]=$port
	echo -e "${YELLOW}se mappeará el puerto ${params[dockerHttpPort]} local con el puerto 80 del contenedor${NC}"
	dockerPorts="${dockerPorts},\"${params[dockerHttpPort]}:80\""
    params[dockerHttpsPort]="9443"
	checkPort ${params[dockerHttpsPort]}
	params[dockerHttpsPort]=$port
	echo -e "${YELLOW}se mapeará el puerto ${params[dockerHttpsPort]} local con el puerto 443 del contenedor${NC}"
	dockerPorts="${dockerPorts},\"${params[dockerHttspPort]}:443\""
fi
params[dockerPorts]="${dockerPorts}]"


###Volúmenes###
params[klearSyncedFolder]=""
grep -iq zendframework ${roleFile}
runKlearStarter=false
if [ "$?" == "0" ]
then  
	echo -e "${GREEN}Carpeta de la librería de Klear (por defecto en '${BLUE}/opt/klear-development${GREEN}'): ${NC}"
	read params[klearLibraryFolder]
	if [ -z "${params[klearLibraryFolder]}" ]
	then
	    params[klearLibraryFolder]="/opt/klear-development"
	fi
	params[klearSyncedFolder]="config.vm.synced_folder \"${params[klearLibraryFolder]}\", \"/opt/klear-development\""
	echo -e "${GREEN}¿Ejecutar klear-starter al terminar?:[Y/n] ${NC}"
	read klearStarter
	if [ "${klearStarter}" = "y" ] || [ "${klearStarter}" = "Y" ] 
	then
	    runKlearStarter=true
	fi
fi

###Database###
params[dataBaseName]=""
params[dataBaseUser]=""
params[dataBasePassword]=""
grep -iq database ${roleFile}
if [ "$?" == "0" ]
then  
	echo -e "${GREEN}Nombre de la base de datos (por defecto ${BLUE}${params[proyectNameToLowwer]}${GREEN}): ${NC}"
	read params[dataBaseName]
	if [ -z "${params[dataBaseName]}" ]
	then
	    params[dataBaseName]=${params[proyectNameToLowwer]}
	fi
	echo -e "${GREEN}Usuario de la base de datos (por defecto ${BLUE}root${GREEN}): ${NC}"
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
fi

params[dImageLine]="d.image = \"${params[dockerImage]}\""
params[dBuildDirLine]='d.build_dir = "\./"'
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

for file in $(find "$dir/.initVagrant/"* -not -name "start.sh" -not -name "README.md")
do
    for i in "${!params[@]}"
    do
        if [ ! -d "$file" ]
        then
        	param=${params[$i]//\//\\\/}
        	param=${param//\#/\\\#}
            regex="s/{{$i}}/${param}/g"
            regex=${regex//\"/\\\"}
            
            sed -i "$regex" $file
            if [ "$?" != "0" ]
            then
            	echo "sed -i \"$regex\" $file"
    		fi
        fi
    done
done

cp -r $dir/.initVagrant/* $dir/
rm -rf $dir/.initVagrant

IFS=$saveIFS

if [ ${runKlearStarter} ]
then
	echo -e "${GREEN}Ejecutando 'composer create-project irontec/klear-starter $dir/temp'.${NC}"

	composer create-project irontec/klear-starter $dir/temp
	mv $dir/temp/* $dir/
	mv $dir/temp/.* $dir/
	rm -rf $dir/temp
fi

echo -e "${GREEN}Se ha configurado correctamente el proyecto para usar con Vagrant, Ansible y Docker."
echo -e "Ejecuta 'vagrant up' para arrancar el contenedor${NC}"

exit 0