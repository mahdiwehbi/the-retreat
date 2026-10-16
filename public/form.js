// Site check questions (test version, inspired by the WASH Assessment Platform criteria).
// Replace these with the real questionnaire when it is ready. Each option's `risk` adds to
// the site's score: 0 = no concern, 3 = high concern.
window.WR_FORM = {
  title: 'Informal settlement site check',
  intro: 'Test version for the retreat. Walk around the site, answer what you see and take the photos.',
  sections: [
    {
      title: 'Site',
      questions: [
        { id: 'site', type: 'text', label: 'Site name or code', required: true },
        { id: 'households', type: 'number', label: 'Number of tents or households (estimate)' },
        { id: 'gps', type: 'gps', label: 'Location' }
      ]
    },
    {
      title: 'Water',
      questions: [
        { id: 'water_source', type: 'choice', label: 'Main drinking water source', options: [
          { label: 'Public water network', risk: 0 }, { label: 'Private well or borehole', risk: 1 },
          { label: 'Water trucking', risk: 2 }, { label: 'Bottled water only', risk: 1 },
          { label: 'Unprotected spring, river or canal', risk: 3 } ] },
        { id: 'water_storage', type: 'choice', label: 'Water storage at household level', options: [
          { label: 'Enough storage, covered', risk: 0 }, { label: 'Enough storage, not covered', risk: 2 },
          { label: 'Not enough storage', risk: 2 }, { label: 'No storage', risk: 3 } ] },
        { id: 'photo_water', type: 'photo', label: 'Photo of the water point or storage' }
      ]
    },
    {
      title: 'Sanitation',
      questions: [
        { id: 'toilet_type', type: 'choice', label: 'Most common toilet type', options: [
          { label: 'Private flush or pour-flush toilet', risk: 0 }, { label: 'Shared toilet (2+ households)', risk: 1 },
          { label: 'Pit latrine without slab', risk: 2 }, { label: 'No toilet / open defecation', risk: 3 } ] },
        { id: 'photo_toilet', type: 'photo', label: 'Photo of a toilet' },
        { id: 'wastewater', type: 'choice', label: 'Where does blackwater go?', options: [
          { label: 'Sewer network', risk: 0 }, { label: 'Holding tank, emptied regularly', risk: 1 },
          { label: 'Cesspit or soak pit', risk: 2 }, { label: 'Open channel, field or stream', risk: 3 } ] },
        { id: 'overflow', type: 'yesno', label: 'Wastewater visible on the ground or overflowing?', yesRisk: 3, noRisk: 0 },
        { id: 'photo_wastewater', type: 'photo', label: 'Photo of the wastewater disposal' }
      ]
    },
    {
      title: 'Hygiene and environment',
      questions: [
        { id: 'handwashing', type: 'yesno', label: 'Handwashing point with soap near the toilets?', yesRisk: 0, noRisk: 2 },
        { id: 'solid_waste', type: 'choice', label: 'Solid waste', options: [
          { label: 'Collected regularly', risk: 0 }, { label: 'Piled on site', risk: 2 }, { label: 'Burned on site', risk: 2 } ] },
        { id: 'eviction', type: 'yesno', label: 'Eviction risk reported by residents?', yesRisk: 2, noRisk: 0 },
        { id: 'notes', type: 'textarea', label: 'Notes' }
      ]
    }
  ],
  // Severity from the total risk score.
  severity: [
    { max: 4, level: 1, label: 'Minimal' },
    { max: 8, level: 2, label: 'Stress' },
    { max: 13, level: 3, label: 'Severe' },
    { max: 18, level: 4, label: 'Extreme' },
    { max: 999, level: 5, label: 'Catastrophic' }
  ]
};
