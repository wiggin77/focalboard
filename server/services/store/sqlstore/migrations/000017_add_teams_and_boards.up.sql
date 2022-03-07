{{if .mysql}}
RENAME TABLE {{.prefix}}workspaces TO {{.prefix}}teams;
ALTER TABLE {{.prefix}}blocks CHANGE workspace_id channel_id VARCHAR(36);
ALTER TABLE {{.prefix}}blocks_history CHANGE workspace_id channel_id VARCHAR(36);
{{else}}
ALTER TABLE {{.prefix}}workspaces RENAME TO {{.prefix}}teams;
ALTER TABLE {{.prefix}}blocks RENAME COLUMN workspace_id TO channel_id;
ALTER TABLE {{.prefix}}blocks_history RENAME COLUMN workspace_id TO channel_id;
{{end}}
ALTER TABLE {{.prefix}}blocks ADD COLUMN board_id VARCHAR(36);
ALTER TABLE {{.prefix}}blocks_history ADD COLUMN board_id VARCHAR(36);

{{- /* cleanup incorrect data format in column calculations */ -}}
{{if .mysql}}
UPDATE {{.prefix}}blocks SET fields = JSON_SET(fields, '$.columnCalculations', cast('{}' as json))  WHERE fields->'$.columnCalculations' = cast('[]' as json);
{{end}}

{{if .postgres}}
UPDATE {{.prefix}}blocks SET fields = fields::jsonb - 'columnCalculations' || '{"columnCalculations": {}}' WHERE fields->>'columnCalculations' = '[]';
{{end}}

{{if .sqlite}}
UPDATE {{.prefix}}blocks SET fields = replace(fields, '"columnCalculations":[]', '"columnCalculations":{}');
{{end}}

{{- /* add boards tables */ -}}
CREATE TABLE {{.prefix}}boards (
    id VARCHAR(36) NOT NULL PRIMARY KEY,

    {{if .postgres}}insert_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),{{end}}
	{{if .sqlite}}insert_at DATETIME NOT NULL DEFAULT(STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),{{end}}
	{{if .mysql}}insert_at DATETIME(6) NOT NULL DEFAULT NOW(6),{{end}}

    team_id VARCHAR(36) NOT NULL,
    channel_id VARCHAR(36),
    created_by VARCHAR(36),
    modified_by VARCHAR(36),
    type VARCHAR(1) NOT NULL,
    title TEXT,
    description TEXT,
    icon VARCHAR(256),
    show_description BOOLEAN,
    is_template BOOLEAN,
    template_version INT NOT NULL DEFAULT 0, 
    {{if .mysql}}
    properties JSON,
    card_properties JSON,
    column_calculations JSON,
    {{end}}
    {{if .postgres}}
    properties JSONB,
    card_properties JSONB,
    column_calculations JSONB,
    {{end}}
    {{if .sqlite}}
    properties TEXT,
    card_properties TEXT,
    column_calculations TEXT,
    {{end}}
    create_at BIGINT,
    update_at BIGINT,
    delete_at BIGINT
) {{if .mysql}}DEFAULT CHARACTER SET utf8mb4{{end}};

CREATE TABLE {{.prefix}}boards_history (
    id VARCHAR(36) NOT NULL,

    {{if .postgres}}insert_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),{{end}}
	{{if .sqlite}}insert_at DATETIME NOT NULL DEFAULT(STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),{{end}}
	{{if .mysql}}insert_at DATETIME(6) NOT NULL DEFAULT NOW(6),{{end}}

    team_id VARCHAR(36) NOT NULL,
    channel_id VARCHAR(36),
    created_by VARCHAR(36),
    modified_by VARCHAR(36),
    type VARCHAR(1) NOT NULL,
    title TEXT,
    description TEXT,
    icon VARCHAR(256),
    show_description BOOLEAN,
    is_template BOOLEAN,
    template_version INT NOT NULL DEFAULT 0, 
    {{if .mysql}}
    properties JSON,
    card_properties JSON,
    column_calculations JSON,
    {{end}}
    {{if .postgres}}
    properties JSONB,
    card_properties JSONB,
    column_calculations JSONB,
    {{end}}
    {{if .sqlite}}
    properties TEXT,
    card_properties TEXT,
    column_calculations TEXT,
    {{end}}
    create_at BIGINT,
    update_at BIGINT,
    delete_at BIGINT,

    PRIMARY KEY (id, insert_at)
) {{if .mysql}}DEFAULT CHARACTER SET utf8mb4{{end}};


{{- /* migrate board blocks to boards table */ -}}
{{if .plugin}}
  {{if .postgres}}
  INSERT INTO {{.prefix}}boards (
      SELECT B.id, B.insert_at, C.TeamId, B.channel_id, B.created_by, B.modified_by, C.type, B.title, (B.fields->>'description')::text,
                 B.fields->>'icon', (B.fields->'showDescription')::text::boolean, (B.fields->'isTemplate')::text::boolean,
                (B.fields->'templateVer')::text::int,
                 '{}', B.fields->'cardProperties', B.fields->'columnCalculations', B.create_at,
                 B.update_at, B.delete_at
          FROM {{.prefix}}blocks AS B
          INNER JOIN channels AS C ON C.Id=B.channel_id
          WHERE B.type='board'
  );
  INSERT INTO {{.prefix}}boards_history (
      SELECT B.id, B.insert_at, C.TeamId, B.channel_id, B.created_by, B.modified_by, C.type, B.title, (B.fields->>'description')::text,
                 B.fields->>'icon', (B.fields->'showDescription')::text::boolean, (B.fields->'isTemplate')::text::boolean,
                (B.fields->'templateVer')::text::int,
                 '{}', B.fields->'cardProperties', B.fields->'columnCalculations', B.create_at,
                 B.update_at, B.delete_at
          FROM {{.prefix}}blocks_history AS B
          INNER JOIN channels AS C ON C.Id=B.channel_id
          WHERE B.type='board'
  );
  {{end}}
  {{if .mysql}}
  INSERT INTO {{.prefix}}boards (
      SELECT B.id, B.insert_at, C.TeamId, B.channel_id, B.created_by, B.modified_by, C.Type, B.title, JSON_UNQUOTE(JSON_EXTRACT(B.fields,'$.description')),
                 JSON_UNQUOTE(JSON_EXTRACT(B.fields,'$.icon')), B.fields->'$.showDescription', B.fields->'$.isTemplate',
                 B.fields->'$.templateVer',
                 '{}', B.fields->'$.cardProperties', B.fields->'$.columnCalculations', B.create_at,
                 B.update_at, B.delete_at
          FROM {{.prefix}}blocks AS B
          INNER JOIN Channels AS C ON C.Id=B.channel_id
          WHERE B.type='board'
  );
  INSERT INTO {{.prefix}}boards_history (
      SELECT B.id, B.insert_at, C.TeamId, B.channel_id, B.created_by, B.modified_by, C.Type, B.title, JSON_UNQUOTE(JSON_EXTRACT(B.fields,'$.description')),
                 JSON_UNQUOTE(JSON_EXTRACT(B.fields,'$.icon')), B.fields->'$.showDescription', B.fields->'$.isTemplate',
                 B.fields->'$.templateVer',
                 '{}', B.fields->'$.cardProperties', B.fields->'$.columnCalculations', B.create_at,
                 B.update_at, B.delete_at
          FROM {{.prefix}}blocks_history AS B
          INNER JOIN Channels AS C ON C.Id=B.channel_id
          WHERE B.type='board'
  );
  {{end}}
{{else}}
  {{if .postgres}}
  INSERT INTO {{.prefix}}boards (
      SELECT id, insert_at, '0', channel_id, created_by, modified_by, 'O', title, (fields->>'description')::text,
                 B.fields->>'icon', (fields->'showDescription')::text::boolean, (fields->'isTemplate')::text::boolean,
                (B.fields->'templateVer')::text::int,
                 '{}', fields->'cardProperties', fields->'columnCalculations', create_at,
                 update_at, delete_at
          FROM {{.prefix}}blocks AS B
          WHERE type='board'
  );
  INSERT INTO {{.prefix}}boards_history (
      SELECT id, insert_at, '0', channel_id, created_by, modified_by, 'O', title, (fields->>'description')::text,
                 B.fields->>'icon', (fields->'showDescription')::text::boolean, (fields->'isTemplate')::text::boolean,
                (B.fields->'templateVer')::text::int,
                 '{}', fields->'cardProperties', fields->'columnCalculations', create_at,
                 update_at, delete_at
          FROM {{.prefix}}blocks_history AS B
          WHERE type='board'
  );
  {{end}}
  {{if .mysql}}
  INSERT INTO {{.prefix}}boards (
      SELECT id, insert_at, '0', channel_id, created_by, modified_by, 'O', title, JSON_UNQUOTE(JSON_EXTRACT(fields,'$.description')),
                 JSON_UNQUOTE(JSON_EXTRACT(fields,'$.icon')), fields->'$.showDescription', fields->'$.isTemplate',
                 B.fields->'$.templateVer',
                 '{}', fields->'$.cardProperties', fields->'$.columnCalculations', create_at,
                 update_at, delete_at
          FROM {{.prefix}}blocks AS B
          WHERE type='board'
  );
  INSERT INTO {{.prefix}}boards_history (
      SELECT id, insert_at, '0', channel_id, created_by, modified_by, 'O', title, JSON_UNQUOTE(JSON_EXTRACT(fields,'$.description')),
                 JSON_UNQUOTE(JSON_EXTRACT(fields,'$.icon')), fields->'$.showDescription', fields->'$.isTemplate',
                 B.fields->'$.templateVer',
                 '{}', fields->'$.cardProperties', fields->'$.columnCalculations', create_at,
                 update_at, delete_at
          FROM {{.prefix}}blocks_history AS B
          WHERE type='board'
  );
  {{end}}
  {{if .sqlite}}
  INSERT INTO {{.prefix}}boards
      SELECT id, insert_at, '0', channel_id, created_by, modified_by, 'O', title, json_extract(fields, '$.description'),
                 json_extract(fields, '$.icon'), json_extract(fields, '$.showDescription'), json_extract(fields, '$.isTemplate'),
                 json_extract(fields, '$.templateVer'),
                 '{}', json_extract(fields, '$.cardProperties'), json_extract(fields, '$.columnCalculations'), create_at,
                 update_at, delete_at
          FROM {{.prefix}}blocks
          WHERE type='board'
  ;
  INSERT INTO {{.prefix}}boards_history
      SELECT id, insert_at, '0', channel_id, created_by, modified_by, 'O', title, json_extract(fields, '$.description'),
                 json_extract(fields, '$.icon'), json_extract(fields, '$.showDescription'), json_extract(fields, '$.isTemplate'),
                 json_extract(fields, '$.templateVer'),
                 '{}', json_extract(fields, '$.cardProperties'), json_extract(fields, '$.columnCalculations'), create_at,
                 update_at, delete_at
          FROM {{.prefix}}blocks_history
          WHERE type='board'
  ;
  {{end}}
{{end}}


{{- /* Update block references to boards*/ -}}
{{if .sqlite}}
  UPDATE {{.prefix}}blocks as B
     SET board_id=(SELECT id FROM {{.prefix}}blocks WHERE id=B.parent_id AND type='board')
   WHERE EXISTS (SELECT id FROM {{.prefix}}blocks WHERE id=B.parent_id AND type='board');

  UPDATE {{.prefix}}blocks as B
     SET board_id=(SELECT GP.id FROM {{.prefix}}blocks as GP JOIN {{.prefix}}blocks AS P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GP.type = 'board')
   WHERE EXISTS (SELECT GP.id FROM {{.prefix}}blocks as GP JOIN {{.prefix}}blocks AS P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GP.type = 'board');

  UPDATE {{.prefix}}blocks as B
     SET board_id=(SELECT GGP.id FROM {{.prefix}}blocks as GGP JOIN {{.prefix}}blocks as GP ON GGP.id=GP.parent_id JOIN {{.prefix}}blocks as P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GGP.type = 'board')
   WHERE EXISTS (SELECT GGP.id FROM {{.prefix}}blocks as GGP JOIN {{.prefix}}blocks as GP ON GGP.id=GP.parent_id JOIN {{.prefix}}blocks as P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GGP.type = 'board');

  UPDATE {{.prefix}}blocks_history as B
     SET board_id=(SELECT id FROM {{.prefix}}blocks_history WHERE id=B.parent_id AND type='board')
   WHERE EXISTS (SELECT id FROM {{.prefix}}blocks_history WHERE id=B.parent_id AND type='board');

  UPDATE {{.prefix}}blocks_history as B
     SET board_id=(SELECT GP.id FROM {{.prefix}}blocks_history as GP JOIN {{.prefix}}blocks_history AS P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GP.type = 'board')
   WHERE EXISTS (SELECT GP.id FROM {{.prefix}}blocks_history as GP JOIN {{.prefix}}blocks_history AS P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GP.type = 'board');

  UPDATE {{.prefix}}blocks_history as B
     SET board_id=(SELECT GGP.id FROM {{.prefix}}blocks_history as GGP JOIN {{.prefix}}blocks_history as GP ON GGP.id=GP.parent_id JOIN {{.prefix}}blocks_history as P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GGP.type = 'board')
   WHERE EXISTS (SELECT GGP.id FROM {{.prefix}}blocks_history as GGP JOIN {{.prefix}}blocks_history as GP ON GGP.id=GP.parent_id JOIN {{.prefix}}blocks_history as P ON GP.id=P.parent_id WHERE P.id=B.parent_id AND GGP.type = 'board');
{{end}}
{{if .mysql}}
    UPDATE {{.prefix}}blocks as B
INNER JOIN {{.prefix}}blocks as P
        ON B.parent_id=P.id
       SET B.board_id=P.id
     WHERE P.type = 'board';

    UPDATE {{.prefix}}blocks as B
INNER JOIN {{.prefix}}blocks as P
        ON B.parent_id=P.id
INNER JOIN {{.prefix}}blocks as GP
        ON P.parent_id=GP.id
       SET B.board_id=GP.id
     WHERE GP.type = 'board';

    UPDATE {{.prefix}}blocks as B
INNER JOIN {{.prefix}}blocks as P
        ON B.parent_id=P.id
INNER JOIN {{.prefix}}blocks as GP
        ON P.parent_id=GP.id
INNER JOIN {{.prefix}}blocks as GPP
        ON GP.parent_id=GPP.id
       SET B.board_id=GPP.id
     WHERE GPP.type = 'board';

    UPDATE {{.prefix}}blocks_history as B
INNER JOIN {{.prefix}}blocks_history as P
        ON B.parent_id=P.id
       SET B.board_id=P.id
     WHERE P.type = 'board';

    UPDATE {{.prefix}}blocks_history as B
INNER JOIN {{.prefix}}blocks_history as P
        ON B.parent_id=P.id
INNER JOIN {{.prefix}}blocks_history as GP
        ON P.parent_id=GP.id
       SET B.board_id=GP.id
     WHERE GP.type = 'board';

    UPDATE {{.prefix}}blocks_history as B
INNER JOIN {{.prefix}}blocks_history as P
        ON B.parent_id=P.id
INNER JOIN {{.prefix}}blocks_history as GP
        ON P.parent_id=GP.id
INNER JOIN {{.prefix}}blocks_history as GPP
        ON GP.parent_id=GPP.id
       SET B.board_id=GPP.id
     WHERE GPP.type = 'board';
{{end}}
{{if .postgres}}
  UPDATE {{.prefix}}blocks as B
     SET board_id=P.id
    FROM {{.prefix}}blocks as P
   WHERE B.parent_id=P.id
     AND P.type = 'board';

  UPDATE {{.prefix}}blocks as B
     SET board_id=GP.id
    FROM {{.prefix}}blocks as P,
         {{.prefix}}blocks as GP
   WHERE B.parent_id=P.id
     AND P.parent_id=GP.id
     AND GP.type = 'board';

  UPDATE {{.prefix}}blocks as B
     SET board_id=GGP.id
    FROM {{.prefix}}blocks as P,
         {{.prefix}}blocks as GP,
         {{.prefix}}blocks as GGP
   WHERE B.parent_id=P.id
     AND P.parent_id=GP.id
     AND GP.parent_id=GGP.id
     AND GGP.type = 'board';

  UPDATE {{.prefix}}blocks_history as B
     SET board_id=P.id
    FROM {{.prefix}}blocks_history as P
   WHERE B.parent_id=P.id
     AND P.type = 'board';

  UPDATE {{.prefix}}blocks_history as B
     SET board_id=GP.id
    FROM {{.prefix}}blocks_history as P,
         {{.prefix}}blocks_history as GP
   WHERE B.parent_id=P.id
     AND P.parent_id=GP.id
     AND GP.type = 'board';

  UPDATE {{.prefix}}blocks_history as B
     SET board_id=GGP.id
    FROM {{.prefix}}blocks_history as P,
         {{.prefix}}blocks_history as GP,
         {{.prefix}}blocks_history as GGP
   WHERE B.parent_id=P.id
     AND P.parent_id=GP.id
     AND GP.parent_id=GGP.id
     AND GGP.type = 'board';
{{end}}


{{- /* Remove boards, including templates */ -}}
DELETE FROM {{.prefix}}blocks WHERE type = 'board';
DELETE FROM {{.prefix}}blocks_history WHERE type = 'board';

{{- /* add board_members */ -}}
CREATE TABLE {{.prefix}}board_members (
    board_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    roles VARCHAR(64),
    scheme_admin BOOLEAN,
    scheme_editor BOOLEAN,
    scheme_commenter BOOLEAN,
    scheme_viewer BOOLEAN,
    PRIMARY KEY (board_id, user_id)
) {{if .mysql}}DEFAULT CHARACTER SET utf8mb4{{end}};

CREATE INDEX idx_boardmembers_user_id ON {{.prefix}}board_members(user_id);

{{if .plugin}}
{{- /* if we're in plugin, migrate channel memberships to the board */ -}}
INSERT INTO {{.prefix}}board_members (
    SELECT B.Id, CM.UserId, CM.Roles, (CM.UserId=B.created_by) OR CM.SchemeAdmin, CM.SchemeUser, FALSE, CM.SchemeGuest
    FROM {{.prefix}}boards AS B
    INNER JOIN ChannelMembers as CM ON CM.ChannelId=B.channel_id
    WHERE NOT B.is_template
);
{{else}}
{{- /* if we're in personal server or desktop, create memberships for everyone */ -}}
INSERT INTO {{.prefix}}board_members
     SELECT B.id, U.id, '', B.created_by=U.id, TRUE, FALSE, FALSE
       FROM {{.prefix}}boards AS B, {{.prefix}}users AS U
       WHERE NOT B.is_template;
{{end}}
