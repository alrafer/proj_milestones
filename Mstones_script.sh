#!/bin/sh

# Calling all the pages we want to process from here.
# Syntax ruby Proj_mstones_update.rb <jira_page_ID> <EPIC_jira_key>. Example: ruby Proj_mstones_update.rb 247857752 OP-11111

# Declare the Jira pages:
jirapageID1=247857752
jirapageID1=247857753
jirapageID1=247857754
jirapageID1=247857755
jirapageID1=247857756

# Build the logfile names
NOW=$(date +"%F_%H_%M_%S")
LOGFILE1="log$jirapageID1-$NOW.log"
LOGFILE2="log$jirapageID2-$NOW.log"
LOGFILE3="log$jirapageID3-$NOW.log"
LOGFILE4="log$jirapageID4-$NOW.log"
LOGFILE5="log$jirapageID5-$NOW.log"

ruby Proj_mstones_update.rb $jirapageID1 OP-11111 &> $LOGFILE1
ruby Proj_mstones_update.rb $jirapageID2 OP-11112 &> $LOGFILE2
ruby Proj_mstones_update.rb $jirapageID3 OP-11113 &> $LOGFILE3
ruby Proj_mstones_update.rb $jirapageID4 OP-11114 &> $LOGFILE4
ruby Proj_mstones_update.rb $jirapageID5 OP-11115 &> $LOGFILE5

