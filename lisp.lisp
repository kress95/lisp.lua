;; block evil global definition
(setmetatable _G
    {table
      (= __index
        (function [_G key]
          (error (.. "variable " key " is not declared") 2)))
      (= __newindex
        (function [_G key]
          (error (.. "declaring global " key " to " (tostring value)) 2)))})

;; atom type
(= [local atom] {table})
