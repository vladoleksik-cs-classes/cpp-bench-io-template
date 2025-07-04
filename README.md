# Fibonacci

> [!NOTE]
> Pentru a redacta cu ușurință soluția, apasă tasta `.` de pe tastatură sau deschide acest assignment în [github.dev](https://github.dev).

## Obiectiv
Scrieți, în fișierul `main.cpp`, programul care, citind din fișierul `input.txt` un număr `n`, va scrie în fișierul `output.txt` al `n`-lea termen al șirului lui Fibonacci, modulo `1000000007`.

## Precizări
Șirul lui Fibonacci se definește drept:
```math
F_n = 
\begin{cases}
0, \quad pentru \; n = 0\\
1, \quad pentru \; n = 1\\
F_{n-1} + F_{n-2}, \quad pentru \; n > 1\\
\end{cases}
```

Așadar, șirul lui Fibonacci este:
`0 1 1 2 3 5 8 13 21`

## Input
Se citește din fișierul `input.txt` numărul $n$.

## Output
Se scrie în fișierul `output.txt` numărul $F_n \; \% \; 1000000007$.

## Restricții
* $0 < n < 2000000000$
* pentru 20 pt., $0 < n < 15$
* pentru încă 60 pt., $15 <= n < 100000$

## Exemplu
### Input
```
8
```
### Output
```
21
```