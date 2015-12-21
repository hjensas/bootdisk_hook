#
# Log debug message to syslog
#
function log_debug() {
  if [ "$LOG_LEVEL" == "debug" ]; then
    if test -n "$1"; then
      logger -p user.info -t bootdisk_hook \
       -- "$(basename $0) DEBUG - $HOOK_EVENT $HOOK_OBJECT - $1"
    fi
  fi
}


#
# Log info message to syslog
#
function log_info() {
  if test -n "$1"; then
    logger -p user.info -t bootdisk_hook \
      -- "$(basename $0) INFO - $HOOK_EVENT $HOOK_OBJECT - $1"
  fi
}

#
# Log error message to syslog
#
function log_err() {
  if test -n "$1"; then
    logger --stderr -p user.err -t bootdisk_hook \
      -- "$(basename $0) ERROR $HOOK_EVENT $HOOK_OBJECT - $1"
  fi
}

# Function to make it easy to get data from the json hook object file
#
#  Usage: 
#    Get hostname:              hook_data host.name
#    Get compute resource ID:   hook_data host.compute_resource_id
# 
#
function hook_data() {
  if [ $# -eq 1 ]; then
    jgrep -s "$1" < $HOOK_OBJECT_FILE
  else
    jgrep "$*" < $HOOK_OBJECT_FILE
  fi
}

