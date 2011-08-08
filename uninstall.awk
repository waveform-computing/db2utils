# For routines, remember whether we're dealing with a function or procedure...
/^CREATE +(FUNCTION|PROCEDURE) +([A-Za-z0-9_#$@]+)\>/ {
	routine=$2;
}
# ...then construct a DROP statement for the SPECIFIC name (must easier than
# dealing with a routine prototype)
/^[[:space:]]*\<SPECIFIC +([A-Za-z0-9_#$@]+)\>/ {
	print "DROP SPECIFIC " routine " " $2 "!";
}

# Everything else just converts easily (we don't bother with indexes here as
# they'll be dropped when the corresponding table is)
/^CREATE +(ALIAS|TABLE|VIEW|ROLE|TRIGGER|VARIABLE) +([A-Za-z0-9_#$@]+)\>/ {
	print "DROP " $2 " " gensub("!$$", "", 1, $3) "!";
}
