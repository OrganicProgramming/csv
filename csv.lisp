(in-package #:csv)

(defconstant +newline-bt+ (char-code #\newline))
(defconstant +quote-bt+ (char-code #\"))

(defmacro do-split ((src delim part) &body body)
  "Split a string src in parts part at each delimiter delim and run code body for each part"
  (alexandria:with-gensyms ((s "stream") (ch "char"))
    `(loop for ,ch across ,src 
           with ,s = (make-string-output-stream) do 
           (if (not (char= ,ch ,delim))
               (write-char ,ch ,s)
               (let ((,part (get-output-stream-string ,s)))
                 ,@body))
           finally 
           (let ((,part (get-output-stream-string ,s)))
             ,@body))))

(defun header->code (header delim vars &optional (ar 'array))
  "Convert the header string into code for csv parsing"
  (let ((field-cnt 0)
        (let-bindings nil)
        (var-len (length vars))
        (var-cnt 0))
    (do-split (header delim hdr)
      (loop for (var-name header-val) in vars do
            (when (equal hdr header-val)
              (incf var-cnt)
              (push `(,var-name (aref ,ar ,field-cnt)) 
                    let-bindings)
              (return)))
      (incf field-cnt))
    (cond ((= var-cnt var-len)
            (list :let-bindings let-bindings 
                  :field-count field-cnt))
          ((> var-cnt var-len) 
           (error "Found duplicates"))
          ((< var-cnt var-len)
           (error "Could not find all variable names")))))

(defun parse-header (file-spec delim vars header-line-number array-name)
  "Read the header from the csv file and generate header specific code"
  (with-open-file (str file-spec :element-type '(unsigned-byte 8))
      (loop for bt = (read-byte str nil) 
            with output = (make-string-output-stream)
            counting (equal bt +newline-bt+) into line-cnt
            while bt do
            (cond ((= line-cnt header-line-number)
                   (when (not (equal bt +newline-bt+))
                     (write-char (code-char bt) output)))
                    ((> line-cnt header-line-number)
                     (return (values (header->code 
                                       (get-output-stream-string output)
                                       delim
                                       vars
                                       array-name) 
                                     (file-position str))))))))

(defmacro do-csv 
  ((file-spec vars &key (delim #\;) (start 0)) &body body)
  "Parse csv file and use header specifics to create convenient bindings to lisp variables"
  (alexandria:with-gensyms 
    (field-val record bt output line-cnt field-cnt str buf idx mode newline-p newfield-p end)
    (multiple-value-bind 
      (code file-pos) 
      (parse-header file-spec delim vars start record)
      (destructuring-bind 
        (&key let-bindings field-count) 
        code
        `(with-open-file (,str ,file-spec :element-type '(unsigned-byte 8))
           (file-position ,str ,file-pos)
           (let ((,buf (make-array 4096 :element-type '(unsigned-byte 8))))
             (loop for ,end = (read-sequence ,buf ,str) while (plusp ,end) 
                   with ,output = (make-string-output-stream)
                   with ,mode = :raw 
                   with ,record = (make-array ,field-count :element-type 'string :initial-element "")
                   with ,line-cnt = 0
                   with ,field-cnt = 0
                   do
                   (loop for ,idx from 0 below ,end
                         for ,bt = (aref ,buf ,idx) 
                         for ,newline-p = (and (= ,bt ,+newline-bt+) 
                                               (equal ,mode :raw))
                         for ,newfield-p = (and (= ,bt ,(char-code delim))
                                                (equal ,mode :raw))
                         do
                         (when ,newline-p (incf ,line-cnt))
                         (when ,newfield-p (incf ,field-cnt))
                         (block continue
                                (cond ((and (equal ,mode :raw) 
                                            (= ,bt ,+quote-bt+))
                                       (setf ,mode :escaped)
                                       (return-from continue))
                                      ((and (equal ,mode :escaped)
                                            (= ,bt ,+quote-bt+))
                                       (setf ,mode :raw)
                                       (return-from continue)))
                                (when 
                                  (not (and (equal ,mode :raw) 
                                            (or (= ,bt ,(char-code delim))
                                                (= ,bt ,+newline-bt+))))
                                  (write-char (code-char ,bt) ,output))
                                (when ,newline-p
                                  (let ((,field-val (get-output-stream-string ,output)))
                                    (incf ,field-cnt)
                                    (setf (aref ,record (- ,field-cnt 1)) 
                                          ,field-val)           
                                    (if (= ,field-cnt ,field-count)
                                        (let ,let-bindings ,@body)
                                        (error (format nil "The number of parsed fields = ~a
                                                            does not match the number of headers = ~a
                                                            at line number = ~a" 
                                                       ,field-cnt ,field-count ,line-cnt)))
                                    (setf ,field-cnt 0)))
                                (when ,newfield-p
                                  (let ((,field-val (get-output-stream-string ,output)))
                                    (setf (aref ,record (- ,field-cnt 1))
                                          ,field-val))))))))))))
