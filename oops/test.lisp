(do
   (do (print 1))

      (= (local a b c) 1 2 3)

      (while true
      (print 2))

      (repeat
      (print 1)
      (print 2)
      until x)

      (return 1)

      (break)

      (goto aa)

      (label aa)

      (for [(i 1) (len aa) 1]
      (print i))

      (for [(i 1) (len aa)]
      (print i))

      (for-in [k v] [(pairs tbl)]
      (print i))

      (if
      [ok (return "ok")]
      [err (return "err")]
      else (return "??"))

      (= (local test)
         (function [a b c]
            (print a b c)) )

      ; binary operators
      (print (+ 1 2 3 4))
      (print (- 1 2 3 4))
      (print (* 1 2 3 4))
      (print (/ 1 2 3 4))
      (print (% 1 2 3 4))
      (print (^ 1 2 3 4))
      (print (.. "1" "2" "3" "4"))

      ; comparison
      (print (== a b c d e f))
      (print (~= a b c d))
      (print (< a b c d))
      (print (<= a b c d))
      (print (> a b c d))
      (print (>= a b c d))

      ; boolean logic
      (print (and true false true false))
      (print (or 1 2 3 4))

      ; unary operators
      (print (not true))
      (print (- 1))
      ( print ( # len )
   )
)
