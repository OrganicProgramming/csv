(defsystem "my-little-csv"
  :author "Jonathan De Ro <chjonadero@gmail.com>"
  :description "A library to read csv files by header name"
  :version "0.0.1"
  :depends-on (:alexandria)
  :components ((:file "package")
               (:file "csv")))
