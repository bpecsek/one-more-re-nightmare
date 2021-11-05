(in-package :one-more-re-nightmare)

(defvar *next-group*)
(defun next-group ()
  (incf *next-group*))

(esrap:defrule escaped-character
    (and #\\ character)
  (:destructure (backslash char)
    (declare (ignore backslash))
    char))

(esrap:defrule special-character
    (or "(" ")" "«" "»" "[" "]" "{" "}" "¬" "~" "|" "&" "*" "∑" "$" "+"))

#|
«expression*»
(expression*)
under-both   & under-both
under-either | under-either
|#

(esrap:defrule literal
    (* (or escaped-character (not special-character)))
  (:destructure (&rest characters)
    (text (coerce characters 'string))))

(esrap:defrule parens
    (and "(" expressions ")")
  (:destructure (left expression right)
    (declare (ignore left right))
    expression))

(esrap:defrule match-group
    (and "«" expressions "»")
  (:around ()
    (let ((group-number (next-group)))
      (destructuring-bind (left expressions right)
          (esrap:call-transform)
        (declare (ignore left right))
        (group expressions group-number)))))

(esrap:defrule kleene
    (and expression "*")
  (:destructure (expression star)
    (declare (ignore star))
    (either (nullable expression)
            (kleene expression))))

(esrap:defrule plus
    (and expression "+")
  (:destructure (expression plus)
    (declare (ignore plus))
    (join expression (kleene expression))))

(esrap:defrule either
    (and under-either "|" (or either under-either))
  (:destructure (e1 bar e2)
    (declare (ignore bar))
    (either e1 e2)))

(esrap:defrule both
    (and under-both "&" (or both under-both))
  (:destructure (e1 bar e2)
    (declare (ignore bar))
    (both e1 e2)))

(esrap:defrule invert
    (and (or "¬" "~") expression*)
  (:destructure (bar expression)
    (declare (ignore bar))
    (invert expression)))

(esrap:defrule universal-set
    (or "∑" "$")
  (:constant (universal-set)))

(esrap:defrule integer
    (+ (or "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"))
  (:lambda (list)
    (parse-integer (format nil "~{~A~}" list))))

(esrap:defrule repeated
    (and expression* "{" integer "}")
  (:destructure (e left count right)
    (declare (ignore left right))
    (reduce #'join (make-array count :initial-element e)
            :key #'unique-tags)))

(esrap:defrule character-range
    (and "[" character "-" character "]")
  (:destructure (left c1 dash c2 right)
    (declare (ignore left dash right))
    (loop for n from (char-code c1) to (char-code c2)
          collect (code-char n) into characters
          finally (return
                    (literal
                     (make-instance 'positive-symbol-set :elements characters))))))

(esrap:defrule expression*
    (or repeated character-range match-group parens invert universal-set literal))

(esrap:defrule under-either
    (or plus kleene expression*))

(esrap:defrule under-both
    (or either under-either))

(esrap:defrule expression
    (or both under-both))

(esrap:defrule two-expressions
    (and expression expressions)
  (:destructure (e1 e2)
    (join e1 e2)))

(esrap:defrule expressions
    (or two-expressions expression))

(defun parse-regular-expression (string)
  (let ((*next-group* 0))
    (values (esrap:parse 'expressions string)
            *next-group*)))
