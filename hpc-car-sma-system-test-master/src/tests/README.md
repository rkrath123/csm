
CLI tools
---------
Source the 'sma_tools' script on the SMA server:
. ./sma_tools
sma_help


Bash best practices
-------------------
By convention, environment variables (PAGER, EDITOR, ..) and internal shell 
variables (SHELL, BASH_VERSION, ..) are capitalized.  All other variable names 
should be lower case.  Remember that variable names are case-sensitive; this 
convention avoids accidentally overriding environmental and internal variables.
If it's your variable, lowercase it. If you export it, uppercase it.

Use set -o errexit (a.k.a. set -e) to make your script exit when a command fails.  add || true to commands that you allow to fail.
Use set -o nounset (a.k.a. set -u) to exit when your script tries to use undeclared variables.
Use set -o xtrace (a.k.a set -x) to trace what gets executed. Useful for debugging (optional).
Use set -o pipefail in scripts to catch mysqldump fails in e.g. mysqldump |gzip. The exit status of the last command that threw a non-zero exit code is returned.

Surround your variables with {}. Otherwise bash will try to access the $ENVIRONMENT_app 
variable in /srv/$ENVIRONMENT_app, whereas you probably intended /srv/${ENVIRONMENT}_app.

if
  (($#))
then
  # We have at least one argument
fi
if
  ((!$#))
then
  # We have no argument
fi

if [ "$?" -eq 0 ]; then
    echo "Conditions verified"
else
    echo "Conditions NOT verified"
fi
