## list-bash-nests.awk
Analyze nests of provided bash script, and list that with the comma delimited format. 

## Descriptions
```
  - Input
    - Bash script
  - Output
    - Comma delimited format
      - Depth,Type,FuncName*,Opening- NR,Opening-RSTART,Closing-NR,Closing-RSTART
        * If type is not "Function", this column will be empty.
    - Example
      - 0,fu,abc,3,1,17,1
  - Types
      Type Name              Output Name     Pattern
    - Function               fu              func(){}
    - Block                  bl              {}
    - Double Quotes          dq              ""
    - Single Quotes          sq              ''
    - Back Quotes            bq              ``
    - Escaped Back Quotes    eb              \`\`
    - Command Substitution   cs              $()
  - Usage
    - Output the list and sort by "Opening NR" and "Opening RSTART"
      - gawk -f list-bash-nests.awk bar.sh | sort -t, -k 4,4n -k 5,5
```

## Example
```gawk -f list-bash-nests.awk tests/input | sort -t, -k 4,4n -k 5,5```
#### Input
```
#!/bin/bash

abc() { # $("comment")
  bar="foo"
  echo "
  $(echo \
    "$(echo '$()' "\"" "${bar}")" \
    `echo $(echo \`echo "a"\`)`
  )"
  d="{\"x\":\"xxx\"}"

  def()

  {
   echo def
  }
}

{
  ghi(){
    echo ghi
  }
}

abc
def
ghi
```
#### Output (sorted by ```sort``` command)
```
0,fu,abc,3,1,17,1
1,dq,,4,7,4,11
1,dq,,5,8,9,4
2,cs,,6,3,9,3
3,dq,,7,5,7,33
4,cs,,7,6,7,32
5,sq,,7,13,7,17
5,dq,,7,19,7,22
5,dq,,7,24,7,31
3,bq,,8,5,8,31
4,cs,,8,11,8,30
5,eb,,8,18,8,29
6,dq,,8,25,8,27
1,dq,,10,5,10,21
1,fu,def,12,3,16,3
0,bl,,19,1,23,1
1,fu,ghi,20,3,22,3
```
## Tested AWK Implementations
This repository tests following AWK implementations.
- ```nawk```
- ```gawk```
- ```mawk```
