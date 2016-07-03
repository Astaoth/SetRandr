#!/bin/bash

VERSION="alpha-05"
CONFIG=~/.config/SetRandr.cfg
ID=""

function usage() {
    echo -e "Auto load xrandr setup according to a previously saved profil."
    echo -e "The first time you will have a screen combinaison, you will choose the screen properties. The next time you will execute this script with the same screen combinaison, it will automatically load your previous xrandr profil."
    echo -e ""
    echo -e "Usage : "
    echo -e "$0 -h | -v | [-c <config file> ] [-set | -del | -reset | -list | -clone <profil name>]"
    echo -e "\t-h : print this help."
    echo -e "\t-v : print version."
    echo -e "\t-c <config file> : use the given config file. By default : ~/.config/SetRandr.cfg"
    echo -e "\t-load <name> : if no name is given, try to load the matching profil or starts the setup (default action). If a profil name is given, try to load the given profil ; if it doesn't exist, do nothing."
    echo -e "\t-silent <name> : like -load, but without any interactions required."
    echo -e "\t-list : list the saved profils."
    echo -e "\t-check <name>: if no name is given, print the matching saved profil of the current screens. If a name is given, display the matching profil.."
    echo -e "\t-save <name> : save the current profil under the given name if any. The name is not mandatory."
    echo -e "\t-save-gen <name> : idem but save the current configuration as a generic profil."
    echo -e "\t-del <name> : if no name is given, deletes the matching profil of the current screens. If a name is given, try to delete the profil which matches it."
    echo -e "\t-setup : executes the profil setup. It sets the screen configuration but doesn't save it."
    echo -e "\t-set <key> <value> : set the <key> to <value> of the current profil in the config file. <key> can be 'name', 'description', of 'cmd'."
    echo -e "\t-id : show the current ID."
    echo -e "\t-examples : show some configuration samples according to the connected screens."
    echo
    echo -e "By default, the profiles are saved to ~/.config/SetRandr.cfg. This is a simple csv file. It is formated like this : "
    echo -e "<profile name>#<description>#<profil ID ; eg : LVDS-0,<screen edid>|VGA-0,<screen edid>>#<xrandr command>"
    echo -e "The second colon is sorted by the screen output name (HDMI-0, LVDS-0, VGA-0 ...)."
    echo -e "The profil name is unique, at the exception of the empty string."
    echo -e "There are two kinds of profils :  - the general ones, with a name and an ID,"
    echo -e "                                  - the generic ones, with a name but no ID,"
    echo -e "The general profils are autoloaded and can have an emmpty name. It is not possible to have more than one profil with a given ID."
    echo -e "The generic profils have no ID. There purpose is to be used as template in order to quickly take a profil or setup a new one when new screens are connected."
    echo
    echo -e "Hints"
    echo -e "\t- If there are any problem of panning enabled with a nVidia driver, try to disable it in the driver configuration."
}

function version() {
    echo "SetRandr version $VERSION."
}

#Get the current ID.
#An ID is the combinaison of the used outputs and the EDID of the connected screens. It returns something like "LVDS-0,edid|VGA-0,edid". The outputs are sorted. So we can't get "VGA-0,edid|LVDS-0,edid"
function getID() {
    #Explication de la commande awk :
    #BEGIN { FS="\n\t"; RS="";} : le séparateur de champ est un retour chariot suivi d'une tabulation, le séparateur d'enregistrement est une ligne vide
    #$0 ~ / connected/ : seul les enregistrements contenant " connected" sont pris en compte (donc les blocs d'écrans branchés)
    #Le gros bloc entre {} : les actions à faire sur l'enregistrement courant - $0
    #match($1,/([A-Z]+[^ ][0-9]+)/,name) : extraction du nom du connecteur (attention, name est un tableau)
    #x=1 ; while($x !~ /.*EDID:.*/) {x++;} : itération sur les champs jusqu'à trouver celui qui nous intéresse
    #x++; end=x+8; for(x ; x<end ; x=x+1) {match($x,/([^ \t]+)/,tmp); edid=edid tmp[0];}; : concaténation de différents champs en supprimant les espaces
    #print name[0]","edid; : affichage du résultat
    
    current_id=$(xrandr --prop | sed -r 's/^([^ \t]+)/\n\1/g' | awk 'BEGIN { FS="\n\t"; RS="";} $0 ~ / connected/ {match($1,/([A-Z]+[^ ][0-9]+)/,name) ; edid="" ; x=1 ; while($x !~ /.*EDID:.*/) {x++;} ; x++; end=x+8; for(x ; x<end ; x=x+1) {match($x,/([^ \t]+)/,tmp); edid=edid tmp[0];} ; print name[0]","edid;}' | sort | sed "N;s/\n/;/g")
    echo $current_id
}

#Change profil name, description, or cmd of the current profil
function set_var() {
    if [[ $# -lt 2 ]] #Check argument number
    then echo "Wrong number of arguments."
	 exit 1
    fi

    #Remove $1 from the argument list in order to write $*
    #This is done because space separated strings are evaluated as few arguments.
    param=$1
    shift

    #Check if the given string doesn't contains '#' since it's the file separator
    if [[ ! $(echo $* | grep "#") == "" ]]
    then echo "'#' is not an allowed character."
	 exit 1
    fi

    #Check if an other has the given profil name, only in case of a profil name change
    if [[ $param == "name" ]] && [[ $# -gt 0 ]] && [[ ! $(grep "^$*#" $CONFIG) == "" ]] && [[ ! $(grep "^$*#" $CONFIG | cut -d '#' -f3) == $ID ]]
    then echo "Profil $name already exists !"
	 exit 1
    fi
    
    line=$(grep "#$ID#" $CONFIG | head -n 1)
    name=$(echo $line | cut -d '#' -f1)
    description=$(echo $line | cut -d '#' -f2)
    cmd=$(echo $line | cut -d '#' -f4)

    if [[ $param == "name" ]]
    then grep -v "#$ID#" $CONFIG > $CONFIG.tmp
	 echo "$*#$description#$ID#$cmd" >> $CONFIG.tmp
	 mv $CONFIG.tmp $CONFIG
    elif [[ $param == "description" ]]
    then grep -v "#$ID#" $CONFIG > $CONFIG.tmp
	 echo "$name#$*#$ID#$cmd" >> $CONFIG.tmp
	 mv $CONFIG.tmp $CONFIG
    elif [[ $param == "cmd" ]]
    then grep -v "#$ID#" $CONFIG > $CONFIG.tmp 
	 echo "$name#$description#$ID#$*" >> $CONFIG.tmp
	 mv $CONFIG.tmp $CONFIG
    else "$1 is not a known argument."
	 exit 1
    fi
}

#Generate some templates which can be used either as a sample config file or in the setup
function generate() {
    outputs=($(xrandr | grep -E "^[A-Z-]+\-[0-9]+.*" | grep -v "disconnected" | cut -d ' ' -f1))

    #clone : comment forcer la résolution des écrans à etre identique ?

    if [[ ${#outputs[*]} -eq 2 ]] #2 écrans
    then echo "(Generic) Cloned screens#${outputs[0]} primary screen, ${outputs[1]} clone of ${outputs[0]}##xrandr --output ${outputs[0]} --primary --auto --rotate normal --output ${outputs[1]} --auto --same-as ${outputs[0]} --rotate normal"
	 echo "(Generic) Horizontal ${outputs[0]} - ${outputs[1]}#Two screens, ${outputs[0]} on the left (primary), ${outputs[1]} on the right##xrandr --output ${outputs[0]} --primary --auto --rotate normal --output ${outputs[1]} --auto --right-of ${outputs[0]} --rotate normal"
	 echo "(Generic) Horizontal ${outputs[1]} - ${outputs[0]}#Two screens, ${outputs[1]} on the left (primary), ${outputs[0]} on the right##xrandr --output ${outputs[1]} --primary --auto --rotate normal --output ${outputs[0]} --auto --right-of ${outputs[1]} --rotate normal"
    elif [[ ${#outputs[*]} -eq 3 ]] #3 écrans
    then echo "(Generic) Horizontal ${outputs[0]} - ${outputs[1]} - ${outputs[2]}#Three screens, ${outputs[0]} on the left, ${outputs[1]} (primary) on the middle, ${outputs[2]} on the right##xrandr --output ${outputs[1]} --primary --auto --rotate normal --output ${outputs[0]} --auto --left-of ${outputs[1]} --rotate normal --output ${outputs[2]} --auto --right-of ${outputs[1]} --rotate normal"
	 echo "(Generic) Horizontal ${outputs[1]} - ${outputs[2]} - ${outputs[0]}#Three screens, ${outputs[1]} on the left, ${outputs[2]} (primary) on the middle, ${outputs[0]} on the right##xrandr --output ${outputs[2]} --primary --auto --rotate normal --output ${outputs[1]} --auto --left-of ${outputs[2]} --rotate normal --output ${outputs[0]} --auto --right-of ${outputs[2]} --rotate normal"
	 echo "(Generic) Horizontal ${outputs[2]} - ${outputs[0]} - ${outputs[1]}#Three screens, ${outputs[2]} on the left, ${outputs[0]} (primary) on the middle, ${outputs[1]} on the right##xrandr --output ${outputs[0]} --primary --auto --rotate normal --output ${outputs[2]} --auto --left-of ${outputs[0]} --rotate normal --output ${outputs[1]} --auto --right-of ${outputs[0]} --rotate normal"
	 echo "(Generic) Horizontal ${outputs[2]} - ${outputs[1]} - ${outputs[0]}#Three screens, ${outputs[2]} on the left, ${outputs[1]} (primary) on the middle, ${outputs[0]} on the right##xrandr --output ${outputs[1]} --primary --auto --rotate normal --output ${outputs[2]} --auto --left-of ${outputs[1]} --rotate normal --output ${outputs[0]} --auto --right-of ${outputs[1]} --rotate normal"
	 echo "(Generic) Horizontal ${outputs[1]} - ${outputs[0]} - ${outputs[2]}#Three screens, ${outputs[1]} on the left, ${outputs[0]} (primary) on the middle, ${outputs[2]} on the right##xrandr --output ${outputs[0]} --primary --auto --rotate normal --output ${outputs[1]} --auto --left-of ${outputs[0]} --rotate normal --output ${outputs[2]} --auto --right-of ${outputs[0]} --rotate normal"
	 echo "(Generic) Horizontal ${outputs[0]} - ${outputs[2]} - ${outputs[1]}#Three screens, ${outputs[0]} on the left, ${outputs[2]} (primary) on the middle, ${outputs[1]} on the right##xrandr --output ${outputs[2]} --primary --auto --rotate normal --output ${outputs[0]} --auto --left-of ${outputs[2]} --rotate normal --output ${outputs[1]} --auto --right-of ${outputs[2]} --rotate normal"
    fi
}

#When the screens are unknown, start a quick setup in order to get a simple working config. The possible config are the stored profils. 
function setup() {
    description=()
    cmd=()
    IFS=$'\n'
    samples=($(generate))
    n=0

    for profil in ${samples[*]}
    do cmd+=($(echo $profil | cut -d '#' -f4))
       echo -e "$n. $(echo $profil | cut -d '#' -f1) : ${cmd[$n]}"
       echo -e "\t$(echo $profil | cut -d '#' -f2)\n"
       n=$(($n+1))
    done
    
    for profil in $(cat $CONFIG)
    do cmd+=($(echo $profil | cut -d '#' -f4))
       echo -e "$n. $(echo $profil | cut -d '#' -f1) : ${cmd[$n]}"
       echo -e "\t$(echo $profil | cut -d '#' -f2)\n"
       n=$(($n+1))
    done
    echo "Please choose a profil number displayed above to clone or type a xrandr cmd in order to use it ([0-9]+ | <xrandr cmd> ) : "
    read choice

    #Check if the given string doesn't contains '#' since it's the file separator
    if [[ ! $(echo $choice | grep "#") == "" ]]
    then echo "'#' is not an allowed character."
	 exit 1
    fi
    
    if [[ $choice =~ ^[0-9]+$ ]]
    then echo "${cmd[$choice]}"
	 eval ${cmd[$choice]}
    else echo $choice
	 eval $choice
    fi
}

#Save the current screen positions to the current profil if exists, or make a new profil.
function save() {
    #Convert current status to xrandr command
    cmd=$(xrandr --current | grep -v "^ " | grep -v "^Screen ." | sed -r 's/disconnected.*/--off/g' | sed 's/connected //g' | sed 's/primary/--primary/g' | sed -r 's/([0-9]+x[0-9]+)\+([0-9]+)\+([0-9]+) +([a-z]*) *\(.*/--mode \1 --pos \2x\3 --rotate \4/g' | sed -r 's/--rotate *$/--rotate normal/g' | sed -r 's/^([^ ]+)/--output \1/g' | tr '\n' ' ' | sed -r 's/^(.*)/xrandr \1/')

    if [[ $1 == "." ]]
    then generic=1
    else generic=0
    fi
    shift

    if [[ $# -gt 0 ]]
    then name=$(echo $*)
    else echo "Please type the profil name : "
	 read name
    fi

    #Check if the given string doesn't contains '#' since it's the file separator
    if [[ ! $(echo $name | grep "#") == "" ]]
    then echo "'#' is not an allowed character."
	 exit 1
    fi

    #If $name is already used by an other id
    if [[ ! $name == "" ]] && [[ ! $(grep "^$name#" $CONFIG | cut -d '#' -f3) == $ID ]]&& [[ ! $(grep "^$name#" $CONFIG | cut -d '#' -f3) == "" ]]
    then echo "Profil $name already exists !"
	 exit 1
    fi
    description=$(grep "#$ID#" $CONFIG | head -n 1 | cut -d '#' -f2)
#    grep -v "#$ID#" $CONFIG
#    echo "$name#$description#$ID#$cmd"
    #    echo
    if [[ $generic -ge 1 ]]
    then echo "Saved as a generic profil."
	echo "$name#$description##$cmd" >> $CONFIG
    else grep -v "#$ID#" $CONFIG > $CONFIG.tmp
	 echo "$name#$description#$ID#$cmd" >> $CONFIG.tmp
	 mv $CONFIG.tmp $CONFIG
    fi
}

# Delete the current screen profil, or if a name is given, the profil which matches the given name.
function delete() {
    if [[ $# -gt 0 ]]
    then
	#Check if the given string doesn't contains '#' since it's the file separator
	if [[ ! $(echo $* | grep "#") == "" ]]
	then echo "'#' is not an allowed character."
	     exit 1
	fi
	
	#grep -v "^$*#" $CONFIG
	grep -v "^$*#" $CONFIG > $CONFIG.tmp
	mv $CONFIG.tmp $CONFIG
    else #grep -v "#$ID#" $CONFIG
	grep -v "#$ID#" $CONFIG > $CONFIG.tmp
	mv $CONFIG.tmp $CONFIG
    fi
}

# Check if there is any profil which matches the current screens or the given profil name. If it is the case, load it, if there is no profil, execute the setup and save the profil.
# First parameter is the mode. Can be "silent" or "interactive". The silent mode will not execut the setup
function load() {
    cmd=""
    mode=$1
    shift
    if [[ $# -gt 0 ]]
    then
	#Check if the given string doesn't contains '#' since it's the file separator
	if [[ ! $(echo $* | grep "#") == "" ]]
	then echo "'#' is not an allowed character."
	     exit 1
	fi
	
	cmd=$(cat $CONFIG | grep "^$*#" | head -n 1 | cut -d '#' -f4)
	if [[ $cmd == "" ]]
	then echo "\"$*\" is not an existing profil."
	     exit 1
	fi
    else cmd=$(cat $CONFIG | grep "#$ID#" | head -n 1 | cut -d '#' -f4)
    fi
    if [[ $(echo "$cmd") != "" ]]
    then echo "Exec : $cmd"
	 exec $cmd
    elif [[ $mode == "interactive" ]]
    then setup
	 save
    else echo "Silent mode, no setup"
    fi 
}

# Check if a profil to the current ID or to the given name exists, and display the lines as in the config file. If there are few profils, display all of them.
function check() {
    if [[ $# -gt 0 ]]
    then
	#Check if the given string doesn't contains '#' since it's the file separator
	if [[ ! $(echo $* | grep "#") == "" ]]
	then echo "'#' is not an allowed character."
	     exit 1
	fi
	
	grep "^$*#" $CONFIG
    else grep "#$ID#" $CONFIG
    fi
}

# List the existing profils.
function list() {
    IFS=$'\n'
    n=0
    for line in $(cat $CONFIG)
    do
	name=$(echo $line | cut -d '#' -f1)
	description=$(echo $line | cut -d '#' -f2)
	screens=$(echo $line | cut -d '#' -f3)
	args=$(echo $line | cut -d '#' -f4)
	
	echo "Profil name : $name"
	echo "Description : $description"
	#TODO : print screen marque and name
	echo -e "Screen(s) : \n\t$(echo $screens | sed 's/,/ : /g' | sed -r 's/;/\n\t/g')"
	#TODO : format
	echo "Command : $args"
	echo ""
	n=$(($n+1))
    done
    echo "$n stored profile(s)."
}

################################################################################
### Entry Point ################################################################
################################################################################

if [[ $# -gt 0 ]] && ( [ $1 = "-v" ] || [ $1 = "--version" ] )
then version
     exit 0
fi

if [[ $# -gt 0 ]] && ( [ $1 = "-h" ] || [ $1 = "--help" ] )
then usage
     exit 0
fi

if [[ $# -gt 0 ]] && [ $1 = "-c" ]
then CONFIG=$2
     shift 2
fi 


if [[ ! -e $(dirname $CONFIG) ]]
then mkdir -p $(dirname $CONFIG)
fi
if [[ ! -d $(dirname $CONFIG) ]]
then echo "$(dirname $CONFIG) exists but is not a folder."
     exit 1
fi
if [[ ! -e $CONFIG ]]
then touch $CONFIG
fi
ID=$(getID)

#echo $current_edid

if [[ $# -eq 0 ]]
then usage
elif [ $1 = "-list" ]
then list
elif [ $1 = "-setup" ]
then setup
elif [ $1 = "-id" ]
then getID
elif [ $1 = "-examples" ]
then generate
elif [ $1 = "-set" ]
then shift
      set_var $*
elif [ $1 = "-save" ]
then shift
     if [[ $# -eq 0 ]]
     then save $ID
     else save $ID $*
     fi
elif [ $1 = "-save-gen" ]
then shift
     if [[ $# -eq 0 ]]
     then save "."
     else save "." $*
     fi
elif [ $1 = "-check" ]
then shift
     if [[ $# -eq 0 ]]
     then check
     else check $*
     fi
elif [ $1 = "-del" ]
then shift
     if [[ $# -eq 0 ]]
     then delete
     else delete $*
     fi
elif [ $1 = "-load" ]
then shift
     if [[ $# -eq 0 ]]
     then load "interactive"
     else load "interactive" $*
     fi
elif [ $1 = "-silent" ]
then shift
     if [[ $# -eq 0 ]]
     then load "silent"
     else load "silent" $*
     fi
else usage
fi

exit 0
