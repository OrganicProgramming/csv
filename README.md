# csv
Small library to read csv files based on the header.

### Download
Download this repository in your local-projects directory of your quicklisp folder:
```
git clone https://github.com/OrganicProgramming/csv
```
Run 
```
(ql:register-local-projects)
(ql:quickload :csv)
```
and you' re good to go!

### Usage

To read the csv file with headers starting at line 3:

name;age;gender  
john;20;Male  
greg;24;Male


```commonlisp
(csv:do-csv ("test.csv" ((nm "name")
                         (ag "age"))
             ;; start is zero based, so for headers on line 3, we set start = 2,
             ;; the default is start = 0 for headers starting at line 1
             :start 2)
  ;; Bind vars nm and ag to values under the headers "name" and "age" respectively
  (print (list nm ag)))

```

### TO DO

-Add support for different encodings.  
-Add support for csv files without headers.
