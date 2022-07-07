# -------------------------------------------------------------------------------------------------
# list-bash-nests.awk -- Analyze nests of provided bash script, and list that with the comma
#                        delimited format.
#
#       - Descriptions
#         - Input
#           - Bash script
#         - Output
#           - Comma delimited format
#             - Depth,Type,FuncName*,Opening- NR,Opening-RSTART,Closing-NR,Closing-RSTART
#               * If type is not "Function", this column will be empty.
#           - Example
#             - 0,fu,abc,3,1,17,1
#         - Types
#             Type Name              Output Name     Pattern
#           - Function               fu              func(){}
#           - Block                  bl              {}
#           - Double Quotes          dq              ""
#           - Single Quotes          sq              ''
#           - Back Quotes            bq              ``
#           - Escaped Back Quotes    eb              \`\`
#           - Command Substitution   cs              $()
#         - Usage
#           - Output the list and sort by "Opening NR" and "Opening RSTART"
#             - gawk -f list-bash-nests.awk bar.sh | sort -t, -k 4,4n -k 5,5n
#
# Version: 0.1.0
# Author: yuxki
# Repository: https://github.com/yuxki/list-bash-nests
# Last Change: 2022/7/7
# License:
# MIT License
#
# Copyright (c) 2022 Yuxki
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# -------------------------------------------------------------------------------------------------
BEGIN {
  stackIdx = 0
  listIdx = 0
}

{
  remains = $0
  lineRStart = 0

  # remove comment
  if (match(remains, /[^${]#/))
    remains = substr(remains, 1, RSTART-1)

  while (1){
    openRStart = 0; openRLength = 0; closeRStart = 0; closeRLength = 0;
    openReg = ""

    # skip if this line remains only spaces
    if (remains ~ /^\s*$/)
      next

    # generate the regular expression that match a opening
    if (! isInCmd(stack, stackIdx)) {
      openReg = "[_a-zA-z][_a-zA-z0-9]* *\\(\\) *{?|{|\"|'|`|\\$\\("
    }
    else if (! isInSQuotes(stack, stackIdx)) {
      openReg = "\\$\\(|`"
      if (! isInDQuotes(stack, stackIdx)) openReg = openReg "|\"|'"
      if (isInBQuotes(stack, stackIdx)) openReg = openReg "|\\\\`"
    }

    # try to match opening and closing
    if (openReg != "" && match(remains, openReg)) {
      openRStart = RSTART
      openRLength = RLENGTH
      isConsumeOp = 1
    }
    if (stackIdx > 0 && match(remains, closeReg(stack, stackIdx))) {
      closeRStart = RSTART
      closeRLength = RLENGTH

      if (openRStart != 0 && openRStart < closeRStart)
        isConsumeOp = 1
      else
        isConsumeOp = 0
    }

    if (! (openRStart == 0 && closeRStart == 0)) {
      if (isConsumeOp) { # consume opening
        if (! isEscaped(openRStart, remains)) {
          opening = substr(remains, openRStart, openRLength)
          type = nestType(opening)
          if (type == "fu") funcName = getFuncName(opening)
          else funcName = ""

          stack[stackIdx] = sprintf("%d", stackIdx) "," type
          stack[stackIdx] = stack[stackIdx] "," funcName
          stack[stackIdx] = stack[stackIdx] "," NR "," (lineRStart + openRStart)
          stackIdx += 1
        }

        # if the function does not opened at this line, getline until match "{"
        if (type == "fu" && opening !~ /{$/) {
          while (getline > 0) {
            lineRStart = 0
            if (match($0, /{/) && ! isEscaped(RSTART, $0)) {
              lineRStart += RSTART
              remains = substr($0, RSTART + RLENGTH)
              break
            }
          }
          continue
        }

        lineRStart += openRStart + openRLength - 1
        remains = substr(remains, openRStart + openRLength)
      }
      else { # consume closing
        if (! isEscaped(closeRStart, remains)) {
          nestList[listIdx++] = stack[--stackIdx] "," NR "," (lineRStart + closeRStart + closeRLength - 1)
        }
        lineRStart += closeRStart + closeRLength - 1
        remains = substr(remains, closeRStart + closeRLength)
      }
      continue
    } # end of consuming remains
    next
  } # end of while loop
}

END {
  for (idx in nestList)
    print nestList[idx]
}

function isIn(stack, stackIdx, typeReg,     array) {
  for (i = 0; i < stackIdx; i++) {
    split(stack[i], array, ",")
    if (array[2] ~ "^" typeReg "$") {
      return 1
    }
  }
  return 0
}

function isInCmd(stack, stackIdx) { return isIn(stack, stackIdx, "dq|sq|bq|cs") }

function isInSQuotes(stack, stackIdx) { return isIn(stack, stackIdx, "sq") }

function isInBQuotes(stack, stackIdx) { return isIn(stack, stackIdx, "dq") }

function isInDQuotes(stack, stackIdx,    array) {
  split(stack[stackIdx - 1], array, ",")
  if (array[2] == "dq")
    return 1
  return 0
}

function nestType(str) {
    if (str ==  "{")
      return "bl"
    else if (str ==  "$(")
      return "cs"
    else if (str ==  "\"")
      return "dq"
    else if (str ==  "'")
      return "sq"
    else if (str ==  "`")
      return "bq"
    else if (str ==  "\\`")
      return "eb"
    else {
      if (str ~ /\(\)/)
        return "fu"
    }

  print "ERROR: " str " is undefined opening string"
  exit 1
}

function closeReg(stack, stackIdx,    array, type) {
  split(stack[stackIdx - 1], array, ",")
  type = array[2]

  if (type ==  "fu")
    return  "}"
  else if (type ==  "bl")
    return  "}"
  else if (type ==  "cs")
    return  ")"
  else if (type ==  "dq")
    return  "\""
  else if (type ==  "sq")
    return  "'"
  else if (type ==  "bq")
    return  "`"
  else if (type ==  "eb")
    return  "\\\\`"

  print "ERROR: " array[2] " is undefined nest type"
  exit 1
}

function isEscaped(rstart, remains) {
  if (rstart == 1)
    return 0
  else if (rstart == 2) {
    if (substr(remains, 1, 1) ~ /\\/)
      return 1
    else
      return 0
  }
  else if (rstart > 2) {
    if (substr(remains, rstart - 2, 2) ~ /[^\\]\\/)
      return 1
    else
      return 0
  }
  else {
    print "ERROR: Expected RSTART is more than 1"
    exit 1
  }
}

function getFuncName(opening) {
  if (match(opening, /^[_a-zA-z][_a-zA-z0-9]*/))
    return substr(opening, RSTART, RLENGTH)
  else
    return ""
}
