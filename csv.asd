(defsystem "csv"
  :description "A library to read csv files by header name"
  :version "0.0.1"
  :depends-on (:alexandria)
  :serial t
  :components ((:file "package")
               (:file "csv")))
