-- Check correctness of an hexagons grid
--
-- Cells must have no overlaps and have a number of
-- intersections with other cells between 2 and 6
--

WITH
 grid AS ( SELECT * FROM CDB_HexagonGrid(ST_MakeEnvelope(10, 10, 20, 20), 2) as cell ),
 igrid AS ( SELECT row_number() over (), cell from grid )

 SELECT count(row_number) as r1, sum(st_npoints(cell)) as r2, 'count / npoints' as err
 FROM igrid g1

UNION ALL

 SELECT g1.row_number as r1, g2.row_number as r2, 'overlap' as err
 FROM igrid g1, igrid g2
 WHERE g2.row_number > g1.row_number AND
       ST_Overlaps(g1.cell, g2.cell)

UNION ALL

 SELECT g1.row_number, count(g2.row_number) as r2, 'n intersections' as err
 FROM igrid g1, igrid g2
 WHERE g1.row_number != g2.row_number AND
       ST_Intersects(g1.cell, g2.cell)
       GROUP BY g1.row_number
       HAVING count(g2.row_number) > 6 OR count(g2.row_number) < 2

	;
