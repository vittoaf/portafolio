/**
 * assertion_helpers.js
 * Generadores reutilizables de consultas de aserciones de calidad de datos.
 */

function assertUnique(targetTableRef, columns) {
  const colList = Array.isArray(columns) ? columns.join(", ") : columns;
  return `
    SELECT
      ${colList},
      COUNT(1) AS duplicate_count
    FROM
      ${targetTableRef}
    GROUP BY
      ${colList}
    HAVING
      COUNT(1) > 1
  `;
}

function assertNotNull(targetTableRef, columns) {
  const cols = Array.isArray(columns) ? columns : [columns];
  const conditions = cols.map(c => `(${c} IS NULL OR TRIM(CAST(${c} AS STRING)) = '')`).join(" OR ");
  return `
    SELECT
      *
    FROM
      ${targetTableRef}
    WHERE
      ${conditions}
  `;
}

function assertReferentialIntegrity(childTableRef, childForeignKey, parentTableRef, parentPrimaryKey) {
  return `
    SELECT
      child.${childForeignKey} AS orphan_key
    FROM
      ${childTableRef} AS child
    LEFT JOIN
      ${parentTableRef} AS parent
      ON child.${childForeignKey} = parent.${parentPrimaryKey}
    WHERE
      child.${childForeignKey} IS NOT NULL
      AND parent.${parentPrimaryKey} IS NULL
  `;
}

function assertCondition(targetTableRef, booleanCondition) {
  return `
    SELECT
      *
    FROM
      ${targetTableRef}
    WHERE
      NOT (${booleanCondition})
  `;
}

module.exports = {
  assertUnique,
  assertNotNull,
  assertReferentialIntegrity,
  assertCondition
};
