#"/bin/bash
# configure.sh - Gerador de Distribuição de Pacotes do Android
# 
# Autor: Marlon Silva Carvalho
# 
# -----------------------------------------------------------------
# Este programa não recebe parâmetros iniciais. Ele é responsável
# em fazer o download da SDK e do Eclipse do Android. Prepara o 
# ambiente para a distribuição dos pacotes.
# -----------------------------------------------------------------
#
# Histórico
# v1.0 - 25/04/2013
#  - Versão inicial
#
# TODO Solicitar o Nome e Senha do usuário no Github na linha de comando.
#
BUNDLE_FILE_NAME="adt-bundle-linux-x86-20130219" # Nome do arquivo do bundle sem a extensão.
BUNDLE_FILE=$BUNDLE_FILE_NAME".zip" # Nome do arquivo com a extensão.
URL_SDK="http://dl.google.com/android/adt/"$BUNDLE_FILE # URL para baixar o bundle.
LOG_ERROR=1 # Constante para o Level de Log para Erros.
LOG_INFO=2  # Constante para o Level de Log para Infos.
PLATFORMS="8,10,16,17" # Quais plataformas do Android vamos gerar pacotes.

BASEDIR=$(dirname $0)
DIR_PKGS=$BASEDIR"/ubuntu-packages"
DIR_PKG_ECLIPSE=$DIR_PKGS"/architectures/i386/android-eclipse/src/data/opt/android/ide/"
DIR_PKG_SDK=$DIR_PKGS"/architectures/all/android-sdk/src/data/opt/android/sdk/"
DIR_PKG_PLATFORMS=$DIR_PKGS"/architectures/all/android-platform-"

clear

# ........................... Definições de Funções .........................

# Exibir um  log na tela.
#
# Parâmetros:
# - 1: Level do Log.
# - 2: Mensagem a ser exibida.
log() {
 if [ $1 -eq $LOG_ERROR  ]; then
   echo -e '\033[31mERRO:\033[m'$2
 elif [ $1 -eq $LOG_INFO ]; then
   echo -e '\033[34mINFO:\033[m'$2
 fi
}

# Verificar se o Maven está instalado na máquina.
# Caso não, encerra o programa.
#
# Autor: Marlon Silva Carvalho
check_mvn_is_installed() {
  mvn -v >/dev/null 2>&1 || { log $LOG_ERROR "Instale primeiro o Maven para prosseguir!"; exit 1; }
}

# Clonar o repositório contendo a estrutura dos pacotes.
#
# Autor: Marlon Silva Carvalho
git_clone_repo() {
  log $LOG_INFO "Clonando o Repositório que contém a estrutura dos pacotes."
  if [ -d $DIR_PKGS ]; then
    rm -r -f $DIR_PKGS
  fi
  git clone https://github.com/exmo/ubuntu-packages.git --quiet
}

# Executar o Maven para Gerar os Pacotes!
#
# Autor: Marlon Silva Carvalho
create_packages_with_maven() {
  log $LOG_INFO "Iniciando a Criação dos Pacotes com o Maven!"
  cd $DIR_PKGS
  mvn -q clean package
}

# Verificar se o Git está instalado na máquina.
# Caso não, encerra o programa.
#
# Autor: Marlon Silva Carvalho
check_git_is_installed() {
  git --version >/dev/null 2>&1 || { log $LOG_ERROR "Instale primeiro o Git para prosseguir!"; exit 1; }
}

# Verificar se o arquivo do Bundle da SDK já foi baixado.
# Caso não, baixar do endereço padrão.
#
# Autor: Marlon Silva Carvalho
get_android_sdk_bundle_file() {
  if [ -f "$BUNDLE_FILE" ]; then
     log  $LOG_INFO "O arquivo ZIP do SDK já existe no diretorio. Continuando a instalação."
  else
     log $LOG_INFO "Baixando o Android SDK Bundle. Aguarde."
     curl -o $BUNDLE_FILE "$URL_SDK"
  fi
}

# Mover os pacotes .deb gerados para a pasta build
#
# Autor: Marlon Silva Carvalho
mv_packages_to_build_folder() {
  log $LOG_INFO "Copiando os pacotes .deb para a pasta de build."

  if [ -d "$BASEDIR/build" ]; then
    rm -r "$BASEDIR/build" >> /dev/null
  fi

  mkdir -p $BASEDIR"/build"
  find ./ -path $BASEDIR"/build" -prune -o -iname "*.deb" -exec cp {} "$BASEDIR/build/" \;
}

# Instalar o plugin do Questoid para visualizar o banco de dados.
# É necessário baixar ele da internet e copiar para a pasta plugins.
#
# Autor: Marlon Silva Carvalho
install_questoid_plugin() {
  log $LOG_INFO "Instalando o Plugin Questoid no Eclipse."
  curl -o com.questoid.sqlitemanager_1.0.0.jar "https://dl.dropboxusercontent.com/u/12435762/com.questoid.sqlitemanager_1.0.0.jar"
  cp com.questoid.sqlitemanager_1.0.0.jar "$DIR_PKG_ECLIPSE/eclipse/plugins"
  rm com.questoid.sqlitemanager_1.0.0.jar
}

# ....................... Fim da Definição de Funções .......................

# Checagem inicial de programas externos necessários para a execução do script.
check_git_is_installed
check_mvn_is_installed

# Vamos pegar o repositório contendo a estrutura dos pacotes.
git_clone_repo

# Fazer o download, se necessário, do arquivo do bundle da SDK.
get_android_sdk_bundle_file

if [ -d $BUNDLE_FILE_NAME ]; then
    log $LOG_INFO "Diretório da SDK já existe. O arquivo já foi descompactado?"
fi 

log $LOG_INFO "Descompactando arquivo. Aguarde."
unzip -o -q $BUNDLE_FILE

log $LOG_INFO "Removendo arquivo."
rm -f $BUNDLE_FILE

cd $BUNDLE_FILE_NAME
cd "sdk/tools"

log $LOG_INFO "Iniciando atualização da SDK do Android. Este processo é BASTANTE demorado."
./android -s update sdk --all --no-ui >> /dev/null

cd "../../../"

# Verificar se já existe um Eclipse no destino. Caso sim, remover esse diretório.
if [ -d $DIR_PKG_ECLIPSE ]; then
  log $LOG_INFO "Removendo instalação antiga do Eclipse."
  rm -r -f $DIR_PKG_ECLIPSE
fi

mkdir -p $DIR_PKG_ECLIPSE

# Mover o novo Eclipse para o diretório de pacotes.
log $LOG_INFO "Movendo o Eclipse."
cp -r -f $BUNDLE_FILE_NAME"/eclipse" $DIR_PKG_ECLIPSE 

log $LOG_INFO "Removendo SDK Antiga."
rm -r -f $DIR_PKG_SDK
mkdir -p $DIR_PKG_SDK

log $LOG_INFO "Movendo a SDK Nova."
cp -r -f $BUNDLE_FILE_NAME"/sdk/extras/" $DIR_PKG_SDK
cp -r -f $BUNDLE_FILE_NAME"/sdk/platform-tools/" $DIR_PKG_SDK
cp -r -f $BUNDLE_FILE_NAME"/sdk/tools/" $DIR_PKG_SDK

IFS=,
platform_versions=''
modules_platforms=''
log $LOG_INFO "Movendo as Plataformas."
for platform in $PLATFORMS; do
  dir_platform=$DIR_PKG_PLATFORMS""$platform"/src/data/opt/android/sdk/"

  platform_versions=$platform_versions'android-platform-'$platform' (>=1.0), '
  modules_platforms="$modules_platforms<module>android-platform-$platform<\/module>"

  # Caso exista o diretório para o pacote.
  if [ -d $DIR_PKG_PLATFORMS""$platform ]; then
    rm -r -f $DIR_PKG_PLATFORMS""$platform
  fi

  cp -r -f "$DIR_PKG_PLATFORMS/" $DIR_PKG_PLATFORMS""$platform

  # Mudar o POM.XML para mudar a String que identifica a versão.
  sed -i "s/platformversion/"$platform"/g" $DIR_PKG_PLATFORMS""$platform'/pom.xml'

  if [ -d $BUNDLE_FILE_NAME"/sdk/add-ons/addon-google_apis-google-"$platform ]; then
    mkdir -p $dir_platform"/add-ons"
    cp -r -f $BUNDLE_FILE_NAME"/sdk/add-ons/addon-google_apis-google-"$platform $dir_platform"/add-ons"
  fi

  if [ -d $BUNDLE_FILE_NAME"/sdk/platforms/android-"$platform ]; then
    mkdir -p $dir_platform"/platforms/"
    cp -r -f $BUNDLE_FILE_NAME"/sdk/platforms/android-"$platform $dir_platform"/platforms/"
  fi

  if [ -d $BUNDLE_FILE_NAME"/sdk/samples/android-"$platform ]; then
    mkdir -p $dir_platform"/samples"
    cp -r -f $BUNDLE_FILE_NAME"/sdk/samples/android-"$platform $dir_platform"/samples/"
  fi

  if [ -d $BUNDLE_FILE_NAME"/sdk/system-images/android-"$platform ]; then
    mkdir -p $dir_platform"/system-images/"
    cp -r -f $BUNDLE_FILE_NAME"/sdk/system-images/android-"$platform $dir_platform"/system-images/"
  fi

done

# Precisamos mudar os POMs informando as plataformas que existem.
sed -i "s/modules_platforms/"$modules_platforms"/g" $DIR_PKGS'/architectures/all/pom.xml'
sed -i "s/platformversion/$platform/g" $DIR_PKG_PLATFORMS""$platform'/pom.xml'
sed -i "s/platformversions/$platform_versions/g" $DIR_PKGS"/architectures/i386/serpro-android/src/deb/control/control"

# Criar a pasta de src/data no pacote serpro-android, pois é necessária e
# ela não existe no repositório por estar vazia.
rm -r -f $DIR_PKG_PLATFORMS
mkdir -p "$DIR_PKGS/architectures/i386/serpro-android/src/data"

# Baixar e instalar o Questoid SQLite Browser
install_questoid_plugin

# Criar os Pacotes.
create_packages_with_maven

# Mover os pacotes para a pasta de build.
mv_packages_to_build_folder

log $LOG_INFO "Processo Finalizado!"
