#!/bin/bash
#===============================================================================
# IDENTIFICATION DIVISION
#        ID SVN:   $Id$
#          FILE:  adv_backup.sh
#         USAGE:  ./config 
#   DESCRIPTION:  Full Backup for Server Config Files
#       OPTIONS:  ---
#  REQUIREMENTS:  mail-utils (apt-get install mail-utils)
#                 dateutils (apt-get install dateutils or yum install dateutils)
#          BUGS:  ---
#         NOTES:  ---
#          TODO:  ---
#        AUTHOR:  Ricardo Barbosa (Rickk Barbosa), rickasd@ig.com.br
#       COMPANY:  ---
#       VERSION:  1.0
#       CREATED:  13/02/2013 09:19:40 AM BRT
#      REVISION:  11/09/2015 00:25:30 AM BRT 
#===============================================================================


### Fist steps
DATE=`date +"%Y-%m-%d"`
if [ ! -f config ]; then 
        exit
else
        . config
fi

echo " " > $LOGFILE
exec 1> $LOGFILE


#Functions
usage() { 
    echo "Usage: $0 -dwm 

                  -d         Daily backup
                  -w         Weekly backup
                  -m         Monthly backup"
     1>&2; exit 1; 
}

make_backup_dir() {
      #Monthly Backup
      MONTH=`date +"%b"`
      #WEEK_NUM=$(dateconv today -f '%c';)
      WEEK_NUM=$(dateutils.dconv today -f '%c';)
      YEAR=`date +"%Y"`
      
      case ${1} in
               "Daily")
                      mkdir -p ${BKP_STORAGE_DIR}/Daily/${DATE}
                      echo "${BKP_STORAGE_DIR}/Daily/${DATE}"
               ;;
               "Weekly")
                      mkdir -p ${BKP_STORAGE_DIR}/Store/${YEAR}/${MONTH}/week${WEEK_NUM}
                      echo "${BKP_STORAGE_DIR}/Store/${YEAR}/${MONTH}/week${WEEK_NUM}"
               ;;
               "Monthly")
                       mkdir -p ${BKP_STORAGE_DIR}/Store/${YEAR}/${MONTH}/
                       echo "${BKP_STORAGE_DIR}/Store/${YEAR}/${MONTH}/"
               ;;

              *)
                      #mv ${DBNAME} dbs/ ;
               ;;
       esac

}


backup_seq() {

      cd ${BKP_STORAGE_DIR}
      #Apt-keys Backup
      AdvPrint "--- exporting apt-keys"
      apt-key exportall > apt_keys.key
      #Current installed DEB Packages"
      AdvPrint "--- generating a installed packages list"
      dpkg --get-selections | awk '{print $1}' > installed_packages.txt

      echo "Backing Up Files"
      tar cvfz ${BKP_FILENAME}_${DATE}.tar.gz ${FILE[@]} apt_keys.key installed_package 1> ./BACKUPED_FILES.txt
      rm apt-keys.key installed_packages.txt


      ###### BACKUP DATABASE #####
      #... If DBNAMES was declared.... 
      if [[ ! -z $DBNAMES ]]; then  
                AdvPrint "--- Backing Up Database"
                mkdir -p ${BKP_STORAGE_DIR}/database
                cd ${BKP_STORAGE_DIR}/database
                for DBNAME in $DBNAMES; do
                       #Start BD Backup
                              mkdir ${DBNAME};
                               cd ${DBNAME};
                               #Backing up Tables
                              TBS=`echo "show tables;" | /usr/bin/mysql -s -u${DBUSER} -p${DBPASSWORD} ${DBNAME}`
                               for TBNAME in $TBS; do
                                      AdvPrint "--- Backup ${DBNAME} [${TBNAME}]";
                                       /usr/bin/mysqldump -eq -u${DBUSER} -p${DBPASSWORD} \
                                               ${DBNAME} ${TBNAME} > ${TBNAME}.sql ;
                                       done ;
                              #Stores DB Grant Too
                              mysql -u${DBUSER} -p${DBPASSWORD} -N -e "SHOW GRANTS FOR ${DBNAME};" > ${DBNAME}_grants.mysql
                              cd ..
                #echo Compressing...
                case $DBCOMPRESS in
                               bzip)
                                      AdvPrint "--- Create a BZIP file for Database ${DBNAME}";
                                       tar cfj ${DBNAME}.tar.bz ${DBNAME};
                                       rm -r ${DBNAME} 2> /dev/null;
                               ;;
                               gzip)
                                      AdvPrint "--- Create a TAR.GZ file for Database ${DBNAME}";
                                       tar cfz ${DBNAME}.tar.gz ${DBNAME};
                                       rm -r ${DBNAME} 2> /dev/null;
                               ;;
                               '')
                                       #mv ${DBNAME}  ;
                               ;;
                
                              *)
                                      #mv ${DBNAME} dbs/ ;
                               ;;
                
                       esac   
      done
      fi
}
      
prune() {
      ### REMOVING OLD BACKUPFILES ###
      AdvPrint "--- Deleting Old BackupFiles";
      cd ${BKP_STORAGE_DIR}
      find . -mtime +${PRUNNING_PERIOD} -exec rm -vrf {} \;
      AdvPrint "--- Done"
      mail -s "Backup of $(hostname;)" ${MAILADM} < $LOGFILE
}


#Script
while getopts "dwm" parameter; do
    case "${parameter}" in
        d)
            #Create BackupDir
            BKP_STORAGE_DIR=$(make_backup_dir Daily;)
            cd ${BKP_STORAGE_DIR}

            #Initializing backup
            backup_seq
            prune
            ;;

        w)
            #Create BackupDir
            BKP_STORAGE_DIR=$(make_backup_dir Weekly;)
            cd ${BKP_STORAGE_DIR}

            #Initializing backup
            backup_seq            
            ;;
        m)
            #Create BackupDir
            BKP_STORAGE_DIR=$(make_backup_dir Monthly;)
            cd ${BKP_STORAGE_DIR}

            #Initializing backup
            backup_seq            
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))
