(defun ejecutar-oz (exprs &optional (env *global-env*))
    ;; Ejecuta una lista de expresiones OZ en el entorno dado (por defecto, el entorno global).
    (dolist (expr exprs)
        ;; Itera sobre cada expresión en la lista.
        (ejecutar-expresion expr env)
    )
)

;; Ejecuta una expresion sobre un entorno dado.
;; Creo que solo faltaria agregar aca el tema de la suma.
(defun ejecutar-expresion (expr env)
    (case (first expr)
        ;; Evalúa el tipo de la primera expresión.
        
        (Browse (browse (second expr) env))
        ;; Si es 'Browse', llama a la función browse con el segundo elemento de la expresión.
        
        (declare (declare-var (second expr) env))
        ;; Si es 'declare', llama a la función declare-var con el segundo y tercer elemento de la expresión.
        
        (local (case (first (third expr)) ;; chequeo que este el in
                (in (case (first (last (third expr))) ;; chequeo que lo ultimo sea end
                    (end (local-vars (second expr) (third expr) env))
                    (t (error "Error: Missing 'end' in introduction of variable(s)"))
                ))
                (t (error "Error: Missing 'in' in introduction of variable(s)"))
            )
        ) ; acá 'local'
        ;; Si es 'local', llama a la función local-vars con el segundo y tercer elemento de la expresión.
        
        (fun (declare-fun (first (second expr)) (cdr (second expr)) (third expr) env))
        ;; Si es 'fun', llama a la función declare-fun con el nombre, parámetros y cuerpo de la función.
        
        (if (eval-if (second expr) (third expr) (fourth expr) env))
        ;; Si es 'if', llama a la función eval-if con la condición, el cuerpo verdadero y el cuerpo falso.
        
        (record (assign-record (second expr) (rest expr) env))
        ;; Si es 'record', llama a la función assign-record con el nombre del record y sus campos.
        
        (field (set-field (second expr) (third expr) (fourth expr) env))
        ;; Si es 'field', llama a la función set-field con el nombre del record, el campo y el valor a asignar.
        
        (t
            (case (second expr)
                (= (equality
                    (first expr)
                    (third expr)
                    env
                ))
                (t (error "Error: expresion no reconocida: ~A" expr))
            )
        )    
    )
)

(defun browse (expr env)
    ;; Evalúa una expresión y la imprime.
    (let ((value (eval-expr expr env)))
      ;; Evalúa la expresión en el entorno dado.
      (if (hash-table-p value)
          ;; Si el valor es una tabla hash (record), lo imprime de manera especial.
          (format t "~{~a: ~a~%~}" (loop for k being the hash-keys of value
                                          using (hash-values v)
                                          collect k collect v))
          ;; Imprime cada clave y valor del record.
          (if (eq value 'nil)
              ;; Si el valor es nil, imprime "nil".
              (format t "nil~%")
              ;; De lo contrario, imprime el valor.
              (format t "~a~%" value)
          )
      )
    )
)

(defun local-vars (vars body env)
    ;; Maneja variables locales y su ámbito.
    (let ((local-env (copy-hash-table env)))
      ;; Crea una copia del entorno para las variables locales.
        (dolist (var vars)
            ;; Itera sobre cada variable local.
            (setf (gethash (first var) local-env) nil)
        )

        (setf body-copy (cdr (reverse (cdr (reverse (copy-list body)))))) ;; me creo una copia del body sin el end y sin el in (ya verifique que estuvieran)
    
        (dolist (stmt body-copy)
            (ejecutar-expresion stmt local-env)
        )
    )
)

(defun eval-if (cond true-body false-body env)
    ;; Evalúa una expresión condicional.
    (if (eval-expr cond env)
        ;; Evalúa la condición.
        (eval-expr true-body env)
        ;; Si es verdadera, evalúa el cuerpo verdadero.
      (eval-expr false-body env)
    )
    ;; Si es falsa, evalúa el cuerpo falso.
)

(defun eval-record (fields env)
    ;; Evalúa una definición de record.
    (let ((record (make-hash-table)))
      ;; Crea una nueva tabla hash para el record.
      (dolist (field fields)
        ;; Itera sobre cada campo del record.
        (let ((key (first field))
              (value (second field)))
          (setf (gethash key record) (eval-expr value env))))
          ;; Evalúa el valor del campo y lo almacena en la tabla hash.
      record)
)

;; Establece un campo de un record.
(defun set-field (record field value env)
    (let ((rec (eval-expr record env)))
        ;; Evalúa la expresión del record.
        (if (hash-table-p rec)
          ;; Si el valor es una tabla hash (record), establece el campo.
          (setf (gethash field rec) (eval-expr value env))
          ;; Evalúa el valor y lo almacena en el campo del record.
          (error "Error: ~a no es un record" record)
        )
    )
)
;; Si el valor no es un record, lanza un error.

(defun eval-expr (expr env)
    ;; Evalúa una expresión en el entorno dado.
    (cond ((symbolp expr) (or (gethash expr env)
                              (error "Error: variable ~a no definida" expr)))
          ;; Si la expresión es un símbolo, busca su valor en la tabla hash del entorno o lanza un error si no se encuentra.
          ((consp expr)
           (case (first expr)
             (quote (second expr))
             ;; Si es una lista citada, devuelve el contenido.
             (fun (declare-fun (second expr) (third expr) (fourth expr) env))
             ;; Si es 'fun', declara una función.
             (if (eval-if (second expr) (third expr) (fourth expr) env))
             ;; Si es 'if', evalúa la condición.
             (record (eval-record (rest expr) env))
             ;; Si es 'record', evalúa la definición del record.
             (field (let* ((record (eval-expr (second expr) env))
                           (field-name (third expr)))
                      (gethash field-name record)))
                      ;; Si es 'field', evalúa el record y obtiene el valor del campo.
             (t (apply (eval-expr (first expr) env)
                       (mapcar (lambda (arg) (eval-expr arg env)) (rest expr))))))
                       ;; De lo contrario, asume que es una llamada a función y evalúa la función y sus argumentos.
          (t expr)
    )
)
;; En cualquier otro caso, devuelve la expresión tal cual (asume que es un valor literal).

;; Definir función > para comparaciones
(setf (gethash '> *global-env*)
        (lambda (a b)
          (> a b))
)
;; Almacena la función de comparación '>' en el entorno global.

(setf (gethash '+ *global-env*)
    (lambda (a b)
      (+ a b))
)
;; Almacena la función '+' en el entorno global.