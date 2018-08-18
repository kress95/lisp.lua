;;;; high priority:
;;;;
;;;; - add codegen
;;;; - add error reporting
;;;;
;;;; medium priority:
;;;;
;;;; - add translists
;;;; - add quasiquote/unquote/unquote-splicing support
;;;; - add compatibility layer translist for luajit 5.1 mode
;;;;
;;;; low priority:
;;;;
;;;; - add 'everything is an expression' translist
;;;; - add sourcemapped error reporting for runtime
;;;; - break compatibility with `#` and `-` readers
;;;; - add a runtime library translist
;;;;
;;;; it will probably need 2kloc :T

;;;; dev mode helpers

;;; disable undefined globals
(setmetatable _G
  {table
    (kv __index
      (function [_ k]
        (error (.. "variable " k " is not declared") 2)))
    (kv __newindex
      (function [_ k v]
        (error (.. "declaring global " k " to " (tostring v)) 2)))})

;;; useful inspect->print function
(local puts) ; (a): a
(do
  (= (local ok inspect) (pcall require "inspect"))
  (if [ok
       (= puts
          (function [item ...]
            (print (inspect item ...))
            (return item)))]
      [else
       (= puts
          (function [item]
            (print item)
            (return item)))]))

;;;; helper functions

;;; throws a previously catched error
(= (local error2); (string, number): nil
   (function [msg lvl]
    (if [(== (type msg) "string")
         (= msg (string-gsub msg ".-%.lua%:%d+%:%s" ""))])
    (= lvl (+ (or lvl 1) 1))
    (error msg lvl)))

;;; checks if a string is a keyword
(local is-keyword) ; (string): boolean
(do
  (= (local keywords)
     {table
      (kv "and" true)
      (kv "break" true)
      (kv "do" true)
      (kv "else" true)
      (kv "elseif" true)
      (kv "end" true)
      (kv "false" true)
      (kv "for" true)
      (kv "function" true)
      (kv "goto" true)
      (kv "if" true)
      (kv "in" true)
      (kv "local" true)
      (kv "nil" true)
      (kv "not" true)
      (kv "or" true)
      (kv "repeat" true)
      (kv "return" true)
      (kv "true" true)
      (kv "until" true)
      (kv "while" true)
      (kv "then" true)})

  (= is-keyword
     (function [str] (return (== (at keywords str) true)))))

;;; try to turn a string into a valid lua identifier, may fail if the string
;;; conflicts with a lua keyword
(local to-identifier) ; (string): string
(do
  (= (local capitalize)
     (function [str] (return (string-gsub str "^%l" string-upper))))

  (= (local pascalize)
     (function [str] (return (string-gsub str "%-(%w+)" capitalize))))

  (= (local escape-char)
     (function [char]
      (return (string-lower (string-format "0x%X_" (string-byte char))))))

  (= to-identifier
     (function [str]
       (if [(string-find str "v4r_") (return false "is prefixed")])
       (if [(string-find str "^[_%a][%-_%w]*$") (= str (pascalize str))])
       (if [(string-find str "^[_%a][%_%w]*$") (return true str)])
       (= str (string-gsub str "^%-" escape-char))
       (= str (pascalize str))
       (= str (string-gsub str "[^_%w]" escape-char))
       (= str (.. "v4r_" str))
       (return true str))))

;;;; required lua functions

(= (local string-gsub ; (str, str, str | (str): str, num): str
          string-sub ; (str, num, num): str
          string-byte ; (str, num?, num?): ...num
          string-char ; (...num): str
          string-find ; (str, str, num, bool): (num, numbe)?
          string-upper ; (str): str
          string-lower ; (str): str
          string-format ; (str, ...any): str
          table-concat ; (table a b, str?, num?, num?): str
          io-open ; (str, str): handle | (nil, str, num)
          io-read ; (handle, str): str
          io-close) ; (handle): nil
   (. string gsub)
   (. string sub)
   (. string byte)
   (. string char)
   (. string find)
   (. string upper)
   (. string lower)
   (. string format)
   (. table concat)
   (. io open)
   (. io read)
   (. io close))

;;;; compiler types

;;; immutable linked lists, metatables are allowed but will only affect the
;;; first cons cell
(local is-list ; (any): bool
       list-create-empty ; (): list
       list-create-with ; (...): list
       list-cons ; (a, list a): list a
       list-head ; (list a): a?
       list-tail ; (list a): list a
       list-is-empty ; (list a): bool
       list-length ; (list a): num
       list-reverse ; (list a): list a
       list-split ; (list a)
       list-to-table ; (list a): table num a
       list-unpack ; (list a): ...a
       list-next ; (_, list a): (list a, a)?
       list-pairs; (list a): ((_, list a): list a, a), list a, list a
       list-to-string); (list a): str
(do
  ;; stores available lists
  (= (local is-list-store) (setmetatable {table} {table (kv __mode "k")}))

  ;; empty list cache (no problem, they are immutable)
  (= (local empty-list) {table})
  (= (at is-list-store empty-list) true)

  ;;; returns true when the value is a linked list
  (= is-list
     (function [value] (return (== (at is-list-store value) true))))

  ;;; returns an empty list
  (= list-create-empty
     (function [] (return empty-list)))

  ;;; creates a list from vararg parameters
  (= list-create-with
     (function [value ...]
      (if [(~= value nil)
           (= (local self) {table value (list-create-with ...)})
           (= (at is-list-store self) true)
           (return self)]
          [else (return empty-list)])))

  ;;; adds an element to the front of a list
  (= list-cons
    (function [self value]
      (= (local self) {table value self})
      (= (at is-list-store self) true)
      (return self)))

  ;;; extracts the first element of the list
  (= list-head
     (function [self] (return (at self 1))))

  ;;; extracts the rest of the list
  (= list-tail
     (function [self] (return (at self 2))))

  ;;; returns true when the list is empty
  (= list-is-empty
    (function [self]
      (return (== self empty))))

  ;;; returns list length
  (= list-length
     (function [self]
      (= (local len) 0)
      (while (at self 2)
        (= len (+ len 1))
        (= self (at self 2)))
      (return len)))

  ;;; reverts the list
  (= list-reverse
    (function [self]
      (= (local other) (list-create-empty))
      (while (at self 2)
        (= other (list-cons other (at self 1)))
        (= self (at self 2)))
      (return other)))

  ;;; splits a list into two at given point
  (= list-split
     (function [self at]
      (= (local left idx right) {table} 0 self)
      (for-in [tail head] [(list-pairs self)]
        (if [(> idx at) (break)])
        (= idx (+ idx 1))
        (= (at left idx) head)
        (= right tail))
      (return (list-create-with (unpack left)) right)))

  ;;; turns the list into a table
  (= list-to-table
     (function [self]
      (= (local arr idx) {table} 0)
      (while (at self 2)
        (= idx (+ idx 1))
        (= (at arr idx) (at self 1))
        (= self (at self 2)))
      (return arr)))

  ;;; converts a list into a table and unpacks it
  (= list-unpack
     (function [self] (return (unpack (list-to-table self)))))

  ;;; returns list tail and its next element
  (= list-next
     (function [_ self]
      (if [self (return (at self 2) (at self 1))])))

  ;;; returns iterator for list pairs for next tail and head
  (= list-pairs
     (function [self] (return list-next self self)))

  ;;; returns a string representation of the list
  (= list-to-string
     (function [self]
      ;  (is-list self)
       (= (local out idx) {table "("} 1)
       (for-in [tail head] [(list-pairs self)]
        (= idx (+ idx 1))
        (if [(is-list head) (= (at out idx) (list-to-string head))]
           [else (= (at out idx) (tostring head))])
        (if [(at tail 2)
             (= idx (+ idx 1))
             (= (at out idx) " ")]))
      (= (at out (+ idx 1)) ")")
      (return (table-concat out "")))))

;;; immutable atom type, used to represent literals and values in s-expressions
(local is-atom ; (any): bool
       atom-create-value ; (a): atom a
       atom-create-symbol ; (str): atom str
       atom-is-symbol ; (atom a): bool
       atom-content) ; (atom a): a
(do
  (= (local atom) {table})

  ;;; returns true when the value is an atom
  (= is-atom
     (function [maybe-self] (return (== (getmetatable maybe-self) atom))))

  ;;; creates an atom for a value
  (= atom-create-value
     (function [content]
      (return
         (setmetatable
          {table (kv content content)
                 (kv symbol false)}
          atom))))

  ;;; creates an atom for a symbol
  (= atom-create-symbol
     (function [content]
      (return
         (setmetatable
          {table (kv content content)
                 (kv symbol true)}
          atom))))

  ;;; returns true when the atom is a symbol
  (= atom-is-symbol
     (function [self]
      (return (and (is-atom self) (at self symbol)))))

  ;;; returns atom content
  (= atom-content
     (function [self] (return (at self content))))

  ;;; returns atom string representation
  (= (. atom __tostring)
     (function [self]
      (= (local content) (atom-content self))
      (if [(atom-is-symbol self)
           (= (local ok msg) (to-identifier content))
           (if [(not ok) (error msg 2)]
               [else (return msg)])]
          [(== (type content) "string") (return (.. "\"" content "\""))]
          [else (return (tostring content))]))))

;;; mutable stream type, used to dynamically read files
(local stream-create ; ((): number?, string): stream
       stream-move
       stream-next)
(do
  (= (local stream) {table})

  ;;; creates a stream that invokes an anonymous function to fetch next chars
  (= stream-create
     (function [get-char source]
        (return (setmetatable {table (kv source source)
                                     (kv get-char get-char)
                                     (kv cache {table})
                                     (kv index 0)
                                     (kv length 0)}
                              stream))))

  ;  stream-from-string
  ;  stream-from-file
  ; ;;; creates a stream that reads the content of a file
  ; (= (local from-file)
  ;    (function [path]
  ;     (= (local file) (assert (io-open path "r")))
  ;     (= (local closed) false)
  ;     (return
  ;       (function []
  ;         (if [closed (return)])
  ;         (= (local char) (io-read file 1))
  ;         (if [char (return (string-byte char 1))]
  ;             [else
  ;              (io-close file)
  ;              (= closed true)]))
  ;       file)))
  ; (= stream-from-file
  ;    (function [path]
  ;     (= (local get-char file) (from-file path))
  ;     (return (stream-create get-char path) file)))

  ; ;;; creates a stream that iterates the content of a string
  ; (= (local from-string)
  ;    (function [str]
  ;     (= (local idx) 0)
  ;     (= (local len) (# str))
  ;     (return
  ;       (function []
  ;         (if [(>= idx len) (return)])
  ;         (= idx (+ idx 1))
  ;         (return (string-byte str idx))))))
  ; (= stream-from-string
  ;    (function [str source]
  ;     (return (stream-create (from-string str) (or source "in-memory")))))

  ;;; returns a new sourcemap for the new character
  ; (= (local get-line-column)
  ;    (function [self]
  ;     (= (local cached) (at (. self cache) (. self length)))
  ;     (if [(not cached) (return 1 0)])
  ;     (= (local sourcemap) (. cached sourcemap))
  ;     (return (sourcemap-to-line sourcemap) (sourcemap-to-column  sourcemap))))
  ; (= (local get-sourcemap)
  ;    (function [self char]
  ;     (= (local line column) (get-line-column self))
  ;     (if [(== char 10)
  ;          (= line (+ line 1))
  ;          (= column 1)]
  ;         [(~= char 13)
  ;          (= column (+ column 1))])
  ;     (return (sourcemap-create (. self source) line column))))

  ;;; push following character to cache
  (= (local next)
     (function [self]
      (= (local index) (. self index))
      (= (local length) (. self length))
      (if [(< index length)
           (= index (+ index 1))
           (= (. self index) index)
           (= (local cached) (at (. self cache) index))
           (return (at cached 1) index)]
          [else
           (= (local char) ((. self get-char)))
           (= (local line column) (get-pos self char))
           (= (local cached) {table char line column})
           (= length (+ length 1))
           (= (at (. self cache) length) cached)
           (= (. self length) length)
           (= (. self index) length)
           (return char length)]

  (= stream-move
     (function [self offset]
      (= (local index) (+ (. self index) offset))
      (= (local length) (. self length))
      (if [(> index length)
           (= (local diff) (- index length))
           (for [(idx 1) diff] (stream-next self))]
          [else
            (if [(< index 0) (= index 0)])
            (= (. self index) index)])
      (return self)))

  (= (. stream __pairs)
     (function [self]
      (return next self))))

;;;; compiler functions
