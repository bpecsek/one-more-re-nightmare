(in-package :one-more-re-nightmare)

(esrap:defrule top-level
    (or two-expressions empty-string))
(esrap:defrule two-expressions
    (and expression top-level)
  (:destructure (a b) (join a b)))
(esrap:defrule expression
    (or either below-either))
(esrap:defrule below-either
    (or both below-both))
(esrap:defrule below-both
    (or join below-join))
(esrap:defrule below-join
    (or invert
        kleene plus repeated
        parens match-group character-range universal-set
        literal empty-string))

(defvar *next-group*)
(defun next-group ()
  (incf *next-group*))
(defvar *group-strings*)

(defun parse-regular-expression (string)
  (let ((*next-group* 0)
        (*group-strings* (make-hash-table)))
    (values (esrap:parse 'top-level string)
            *next-group*
            (coerce (cons string
                          (loop for group from 1 to *next-group*
                                for (s . e) = (gethash group *group-strings*)
                                collect (subseq string s e)))
                    'vector))))

;;; Parens
(esrap:defrule parens
    (and "(" expression ")")
  (:destructure (left expression right)
    (declare (ignore left right))
    expression))

(esrap:defrule match-group
    (and "«" expression "»")
  (:around (esrap:&bounds start end)
    (let ((group-number (next-group)))
      (destructuring-bind (left expressions right)
          (esrap:call-transform)
        (declare (ignore left right))
        (setf (gethash group-number *group-strings*)
              (cons start end))
        (group expressions group-number)))))

;;; Binary operators
(esrap:defrule either
    (and below-either "|" (or either below-either))
  (:destructure (e1 bar e2)
    (declare (ignore bar))
    (either e1 e2)))

(esrap:defrule both
    (and below-both "&" (or both below-both))
  (:destructure (e1 bar e2)
    (declare (ignore bar))
    (both e1 e2)))

(esrap:defrule join
    (and below-join (or join below-join))
  (:destructure (e1 e2) (join e1 e2)))

;;; Repeats
(defun empty-match (expression)
  (trivia:ematch (nullable expression)
    ((empty-set) (empty-set))
    ((empty-string) (empty-string))
    ((tag-set s) (tag-set (loop for (s . nil) in (unique-assignments s)
                                collect (cons s 'position))))))

(defun clear-registers (expression)
  (join (tag-set
         (loop for ((v nil) . nil) in (tags expression)
               collect (cons (list v (tag-gensym)) 'nil)))
        expression))

(esrap:defrule kleene
    (and below-join "*")
  (:destructure (expression star)
    (declare (ignore star))
    (either (empty-match expression)
            (kleene (clear-registers expression)))))

(esrap:defrule plus
    (and below-join "+")
  (:destructure (expression plus)
    (declare (ignore plus))
    (join expression (either (empty-match expression) (kleene (clear-registers expression))))))

(esrap:defrule repeated
    (and below-join "{" integer "}")
  (:destructure (e left count right)
    (declare (ignore left right))
    (reduce #'join (make-array count :initial-element (clear-registers e))
            :key #'unique-tags)))

(esrap:defrule invert
    (and (or "¬" "~") below-join)
  (:destructure (bar expression)
    (declare (ignore bar))
    (invert expression)))

;;; "Terminals"
(esrap:defrule universal-set
    "$"
  (:constant (literal +universal-set+)))

(esrap:defrule integer
    (+ (or "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"))
  (:lambda (list)
    (parse-integer (format nil "~{~A~}" list))))

(esrap:defrule character-range-character
    (not (or (or "-" "]" "[" "\\"))))

(esrap:defrule character-range-range
    (and character-range-character "-" character-range-character)
  (:destructure (low dash high)
    (declare (ignore dash))
    (symbol-range (char-code low) (1+ (char-code high)))))

(esrap:defrule character-range-single
    (or character-range-character escaped-character)
  (:lambda (character)
    (singleton-set (char-code character))))

(esrap:defrule character-range
    (and "[" (esrap:? "¬")
         (* (or character-range-range character-range-single))
         "]")
  (:destructure (left invert ranges right)
    (declare (ignore left right))
    (let ((sum (reduce #'set-union ranges
                       :initial-value +empty-set+)))
      (literal (if invert (set-inverse sum) sum)))))

(esrap:defrule escaped-character
    (and #\\ character)
  (:destructure (backslash char)
    (declare (ignore backslash))
    char))

(esrap:defrule special-character
    (or "(" ")" "«" "»" "[" "]" "{" "}" "¬" "~" "|" "&" "*" "$" "+"))

(esrap:defrule literal
    (or escaped-character (not special-character))
  (:lambda (character) (literal (symbol-set (char-code character)))))

(esrap:defrule empty-string
    ""
  (:constant (empty-string)))
