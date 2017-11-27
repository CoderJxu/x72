scriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ -f "${scriptPath}/lib/functions.sh" ]]; then
  source "${scriptPath}/lib/functions.sh"
else
  echo "missing file: /lib/functions.sh"
  exit 1
fi

