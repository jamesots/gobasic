1 PRINT "Testing_the_BASIC_compiler"
10 LET A = 0
11 LET B = 1
12 PRINT A
13 PRINT B
20 FOR I = 0 TO 20
30 LET C = A + B
40 LET A = B
50 LET B = C
60 PRINT C
70 NEXT I
80 IF 3 < 2 THEN PRINT 500
90 LET A = 4
100 LET B = 8
110 IF TRUE AND TRUE THEN PRINT 110
120 IF 1 < 2 AND NOT ( 13 < 4 ) THEN PRINT 120
121 LET A = 2
122 LET B = 3
123 LET C = 4
130 PRINT 2 + 3 * 4
131 PRINT A + B * C
132 PRINT A + B * 4
133 PRINT 2 + B * C
134 PRINT 2 + 3 * C
135 PRINT A + 3 * 4
140 PRINT "Done"
