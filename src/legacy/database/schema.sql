CREATE TYPE user_role AS ENUM ('GOMUser', 'GOMSuperUser', 'FHUser', 'WebsiteOnlyUser', 'User');

CREATE TYPE photo_type AS ENUM (
  'case', 'funeral_home_logo', 'funeral_home_icon', 'user_profile', 'system',
  'case_gift', 'product', 'goods_services_contract', 'supplier', 'task_location',
  'tree_project_hero', 'tree_project_detail', 'theme'
);

CREATE TYPE stream_device_type AS ENUM ('mevoPlus', 'mevoStart', 'cellPhone', 'tablet', 'otherCamera');

CREATE TABLE environment (
  level                 TEXT NOT NULL DEFAULT 'app',
  key                   TEXT NOT NULL,
  value                 TEXT NOT NULL,
  description           TEXT NOT NULL DEFAULT '',
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY           (level, key)
);

CREATE TYPE feature_type AS ENUM ('standard', 'setup', 'demo', 'app_subscription');

CREATE TYPE feature_group AS ENUM ('case_management', 'gather_universal', 'website', 'keeptrack', 'live_streaming', 'remember_pages', 'app_subscription', 'demo', 'setup');

CREATE TABLE feature (
  key                   TEXT PRIMARY KEY,
  label                 TEXT NOT NULL,
  description           TEXT NOT NULL,
  -- default setting for this flag while FH in live mode
  default_state         BOOLEAN NOT NULL DEFAULT FALSE,
  -- default setting for this flag while FH in demo mode
  demo_default_state    BOOLEAN NOT NULL DEFAULT FALSE,
  -- indicates where this flag is configured
  type                  feature_type NOT NULL DEFAULT 'standard',
  feature_group         feature_group NOT NULL DEFAULT 'case_management',
  rank_in_group         REAL NOT NULL DEFAULT 0
);

CREATE TYPE public.moderation_status AS ENUM (
  'approved',
  'blocked',
  'pending'
);

CREATE TABLE public.photo (
  id                    SERIAL PRIMARY KEY,
  uploaded_by           INTEGER NOT NULL, -- will be foreign key to user_profile
  public_id             TEXT UNIQUE NOT NULL,
  width                 INTEGER NOT NULL DEFAULT 0,
  height                INTEGER NOT NULL DEFAULT 0,
  photo_type            photo_type NOT NULL,
  deleted_by            INTEGER, -- will be foreign key to user_profile
  deleted_time          TIMESTAMP WITH TIME ZONE,
  purged_time           TIMESTAMP WITH TIME ZONE,
  moderation_status     public.moderation_status NOT NULL DEFAULT 'pending',
  moderation_reason     TEXT,
  moderation_time       TIMESTAMP WITH TIME ZONE,
  moderation_required   BOOLEAN NOT NULL DEFAULT TRUE,
  -- moderated_by          INTEGER REFERENCES public.user_profile(id), -- added after user_profile table creation
  external_id           TEXT, -- will generally be the URL we scraped it from
  -- data_source        dataload.data_source
  image_hash            TEXT NOT NULL
);

CREATE INDEX photo_moderation_status_idx ON photo(moderation_status);
CREATE INDEX photo_moderation_time_idx ON photo(moderation_time);

CREATE TABLE photo_view (
  id                    SERIAL PRIMARY KEY,
  photo_id              INTEGER NOT NULL REFERENCES photo(id) ON DELETE CASCADE,
  transformations       JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE INDEX photo_view_photo_idx ON photo_view(photo_id);

CREATE TABLE google_calendar (
  id                    SERIAL PRIMARY KEY,
  name                  TEXT NOT NULL,
  google_id             TEXT UNIQUE NOT NULL,
  sync_token            TEXT,
  sync_max_date         TIMESTAMP WITH TIME ZONE,
  last_failure_time     TIMESTAMP WITH TIME ZONE,
  last_failure_message  TEXT,
  consecutive_failure_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE public.address (
  id                  SERIAL PRIMARY KEY,
  address1            TEXT NOT NULL,
  address2            TEXT,
  city                TEXT NOT NULL,
  state               TEXT NOT NULL,
  country             TEXT,
  postal_code         TEXT,
  timezone            TEXT,
  description         TEXT NOT NULL,
  long_address        JSONB NOT NULL DEFAULT '{}'::JSONB,
  use_description     BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT has_valid_timezone CHECK (timezone IS NULL OR timezone != '')
);

CREATE TYPE entity_type AS ENUM ('customer', 'vendor', 'gather', 'insurer', 'person');

CREATE TABLE public.entity (
    id                  SERIAL PRIMARY KEY,
    external_id         TEXT,
    title               TEXT,
    fname               TEXT NOT NULL,
    mname               TEXT,
    lname               TEXT NOT NULL,
    email               TEXT,
    -- email_verified      BOOLEAN DEFAULT FALSE NOT NULL,
    email_verified_time TIMESTAMP WITH TIME ZONE,
    email_uuid          UUID UNIQUE NOT NULL DEFAULT extensions.gen_random_uuid(), 
    phone               TEXT,
    work_phone          TEXT,
    home_phone        TEXT,
    -- phone_verified      BOOLEAN DEFAULT FALSE NOT NULL,
    phone_verified_time TIMESTAMP WITH TIME ZONE,
    phone_uuid          UUID UNIQUE NOT NULL DEFAULT extensions.gen_random_uuid(),
    type                entity_type NOT NULL,
    home_address_id     INTEGER REFERENCES public.address(id),
    billing_address_id  INTEGER REFERENCES public.address(id),
    is_deceased         BOOLEAN DEFAULT FALSE NOT NULL,
    photo_view_id       INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
    state_license_number  TEXT,
    organization_id     INTEGER, -- foreign key to organization table
    org_role            TEXT,
    fax_number          TEXT,
    suffix              TEXT
);

CREATE INDEX entity_photo_view_idx ON entity(photo_view_id);

-- ROSEBERRY is no longer used, but we're keeping it in the database for backwards compatibility
CREATE TYPE ledger_extract_type AS ENUM ('QB_ZEDAXIS', 'ROSEBERRY','FULL', 'QB_ZEDAXIS_NOFEES', 'SAAS_ANT');

CREATE TYPE calendar_view_type AS ENUM ('expanded', 'collapsed');

CREATE TABLE user_profile (
  id                      SERIAL PRIMARY KEY,
  uniqueid                UUID NOT NULL DEFAULT extensions.gen_random_uuid() UNIQUE,
  password                TEXT NOT NULL DEFAULT 'NOTSET', -- See https://www.meetspaceapp.com/2016/04/12/passwords-postgresql-pgcrypto.html
  reset_code              TEXT,
  reset_expires           TIMESTAMP WITH TIME ZONE,
  email                   TEXT UNIQUE,
  role                    user_role NOT NULL,
  phone                   TEXT UNIQUE, -- i.e. +15555555551 (where +1 is US country code)
  invited_by              INTEGER NOT NULL REFERENCES user_profile(id),
  invited_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_time            TIMESTAMP WITH TIME ZONE,
  entity_id               INTEGER UNIQUE NOT NULL,
  is_family_view_on       BOOLEAN NOT NULL DEFAULT FALSE,
  selected_calendar_view  calendar_view_type NOT NULL DEFAULT 'expanded',
  show_payments_on_statement BOOLEAN NOT NULL DEFAULT FALSE,
  advert_hidden_time      TIMESTAMP WITH TIME ZONE,
  CONSTRAINT has_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

-- user_profile_invited_time_idx NOT ADDED YET
CREATE INDEX user_profile_invited_time_idx ON user_profile(invited_time);

-- Add foreign keys for photo table
-- should only be null if the uploader deletes their account
ALTER TABLE photo ADD FOREIGN KEY (uploaded_by) REFERENCES user_profile(id) ON DELETE SET NULL;
ALTER TABLE photo ADD FOREIGN KEY (deleted_by) REFERENCES user_profile(id) ON DELETE SET NULL;

ALTER TABLE public.photo ADD COLUMN moderated_by INTEGER REFERENCES public.user_profile(id);

CREATE TABLE public.s3_file (
  id                        SERIAL PRIMARY KEY,
  name                      TEXT NOT NULL,
  suffix                    TEXT NOT NULL,
  path                      TEXT NOT NULL,
  size                      INTEGER,
  hash                      TEXT NOT NULL, -- SHA-256 of the binary data
  mimetype                  TEXT NOT NULL,
  uploaded_by               INTEGER NOT NULL REFERENCES user_profile(id),
  uploaded_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP, 
  deleted_by                INTEGER REFERENCES user_profile(id),
  deleted_time              TIMESTAMP WITH TIME ZONE,
  purged_time               TIMESTAMP WITH TIME ZONE
);

-- Case options function constant
CREATE FUNCTION default_case_options()
RETURNS JSONB AS
$$
  SELECT '{
    "remember_page": true,
    "cover_photo": true,
    "life_span": true,
    "inscription": true,
    "obituary": true,
    "casket_bearers": true,
    "service_details": true,
    "events": true,
    "flowers_and_cards": true,
    "go_fund_me": false,
    "memories_section": true,
    "guest_book": true,
    "embed_memorial_video": true,
    "guest_payment": true,
    "share_FACEBOOK": true,
    "share_MESSENGER": true,
    "share_TWITTER": true,
    "share_WHATSAPP": true,
    "share_LINKEDIN": true,
    "share_EMAIL": true,
    "share_SMS": true,
    "share_SHARE": true,
    "share_QRCODE": true,
    "share_LINK": true,
    "show_photos": true,
    "hanging_photos": true,
    "sell_flowers": true,
    "plant_trees": true,
    "remember_page_creation": true,
    "remember_page_indexing": true,
    "remember_book_ad": true
  }'::JSONB
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE
;


CREATE TABLE app_permission (
  app_permission    TEXT NOT NULL, 
  recommended_value BOOLEAN NOT NULL,
  PRIMARY KEY (app_permission)
);



CREATE OR REPLACE FUNCTION default_permissions()
RETURNS JSONB AS 
$$
  SELECT JSONB_OBJECT_AGG(app_permission, recommended_value) FROM app_permission;
$$ LANGUAGE sql
;

CREATE OR REPLACE FUNCTION default_permissions(funeral_home_id INTEGER) 
RETURNS JSONB AS 
$$
  DECLARE
    result JSONB;
  BEGIN
  SELECT COALESCE(
    default_permissions,
    default_permissions()
  ) INTO result
  FROM funeral_home WHERE id = funeral_home_id;
  IF NOT FOUND THEN
    SELECT default_permissions() INTO result;
  END IF;
  RETURN result;
  END;
$$ LANGUAGE plpgsql
;

-- APP-1094 create case_number based on sequence template
CREATE TABLE public.case_number_template (
  id                    SERIAL PRIMARY KEY,
  template              TEXT NOT NULL DEFAULT '<YYYY>-[0000INC]',
  template_name         TEXT NOT NULL,
  starting_sequence     INTEGER NOT NULL DEFAULT 1,
  description           TEXT
);  

CREATE TABLE public.case_number_sequence (
  case_number_template_id INTEGER NOT NULL REFERENCES public.case_number_template(id), 
  pattern                 TEXT NOT NULL, -- this is the first pass after replacing the < and > with the actual values
  next_in_sequence        INTEGER NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX case_number_sequence_template_id_pattern ON public.case_number_sequence (case_number_template_id, pattern);


CREATE TABLE public.funeral_home_group (
  id                      SERIAL PRIMARY KEY,
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  name                    TEXT NOT NULL
);

-- APP-3756 new funeral home status
CREATE TYPE onboarding_status_type AS ENUM ('prospect', 'onboarding', 'adoption', 'steady_state', 'canceled');

-- APP-3891 Guest payment display option type
CREATE TYPE guest_payment_display_option_type AS ENUM ('statement_values', 'outstanding', 'progress', 'none');

-- APP-4251 Florist algorithm type
CREATE TYPE florist_algorithm_type AS ENUM ('round_robin', 'ranked');

-- APP-4319 Remember Page Display Font type
CREATE TYPE hero_font_type AS ENUM (
    'GreatVibes',
    'EBGaramond',
    'EduNSWACTHandPre',
    'Lexend',
    'TradeWinds',
    'Sunshiney',
    'FiraCode',
    'Sancreek',
    'Orbitron',
    'Italianno',
    'Fascinate',
    'Merienda',
    'DynaPuff',
    'Montserrat',
    'SpecialElite',
    'Rancho'
);

CREATE TABLE funeral_home (
  id                    SERIAL PRIMARY KEY,
  group_id              INTEGER NOT NULL REFERENCES public.funeral_home_group(id),
  name                  TEXT NOT NULL,
  key                   TEXT UNIQUE NOT NULL,
  phone                 TEXT NOT NULL,
  email                 TEXT NOT NULL,
  video_embed_code      TEXT,
  photo_view_id         INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
  theme_photo_view_id   INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
  icon_view_id          INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
  theme_icon_view_id    INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
  custom_assets         JSONB NOT NULL DEFAULT '{"themeColor": "#757575"}'::jsonb,
  address_id            INTEGER NOT NULL REFERENCES address(id),
  stripe_customer       TEXT,
  stripe_account        TEXT UNIQUE,
  stripe_location       TEXT,
  ledger_extract_type   ledger_extract_type NOT NULL DEFAULT 'QB_ZEDAXIS',
  qb_tax_rate           DECIMAL(7, 4) NOT NULL DEFAULT 0.0,
  google_calendar_creds JSONB,
  google_calendar_webhook JSONB,
  google_calendar_id    INTEGER REFERENCES google_calendar(id) ON DELETE SET NULL,
  gcal_connect_start_time TIMESTAMP WITH TIME ZONE, -- NULL == no connect in progress
  gcal_disconnect_start_time TIMESTAMP WITH TIME ZONE, -- NULL == no disconnect in progress
  is_demo               BOOLEAN NOT NULL DEFAULT TRUE,
  is_test               BOOLEAN NOT NULL DEFAULT FALSE,
  started_time          TIMESTAMP WITH TIME ZONE, -- NULL until onboarding is payed
  deleted_time          TIMESTAMP WITH TIME ZONE,
  florist_one_affiliate TEXT,
  florist_one_facility  INTEGER,
  florist_1day_lead_time BOOLEAN NOT NULL DEFAULT TRUE,
  ext_flower_store_url  TEXT,
  hidden_flower_categories TEXT[],
  is_startup_enabled    BOOLEAN NOT NULL DEFAULT FALSE,
  startup_headline_title TEXT DEFAULT NULL ,
  startup_main_message  TEXT DEFAULT NULL ,
  startup_documents_header TEXT DEFAULT NULL, 
  startup_button_text   TEXT DEFAULT NULL, 
  startup_button_helper_text TEXT DEFAULT NULL,
  default_case_options  JSONB NOT NULL DEFAULT default_case_options(),
  -- default_dc_config_id     INTEGER NOT NULL REFERENCES public.death_certificate_config(id) -- added later
  default_permissions   JSONB NOT NULL DEFAULT default_permissions(),
  website_url           TEXT,
  default_obit_instructions TEXT NOT NULL DEFAULT '',
  case_number_template_id INTEGER REFERENCES public.case_number_template(id),
  branch_id             TEXT,
  hlc_ext_id            TEXT DEFAULT NULL,
  onboarding_status     onboarding_status_type NOT NULL DEFAULT 'prospect',
  guest_payment_display_option guest_payment_display_option_type NOT NULL DEFAULT 'none',
  is_overpayment_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  is_prepayment_enabled  BOOLEAN NOT NULL DEFAULT FALSE,
  florist_algorithm     florist_algorithm_type NOT NULL DEFAULT 'round_robin'::florist_algorithm_type,
  hero_font             hero_font_type NOT NULL DEFAULT 'GreatVibes'::hero_font_type,
  last_florist_id       INTEGER
);

CREATE INDEX funeral_home_group_id_idx ON funeral_home(group_id);

CREATE TYPE public.funeral_home_log_action AS ENUM ('feature_changed', 'column_changed');

CREATE TABLE public.funeral_home_log (
  id                      SERIAL PRIMARY KEY,
  funeral_home_id         INTEGER NOT NULL REFERENCES public.funeral_home(id),
  action_type             public.funeral_home_log_action NOT NULL,
  feature                 TEXT REFERENCES public.feature(key),
  column_name             TEXT, -- i.e. CASE_MANAGEMENT | group_id
  old_value               TEXT NOT NULL, -- i.e. FALSE           | 1
  new_value               TEXT NOT NULL, -- i.e. TRUE            | 2
  note                    TEXT,
  action_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  action_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  CONSTRAINT has_either_feature_or_column CHECK ((feature IS NULL) != (column_name IS NULL)) -- basically an XOR
);

CREATE TYPE public.org_type AS ENUM (
  'cemetery',
  'church',
  'competitor',
  'crematory',
  'florist',
  'government_agency',
  'hospital',
  'nursing_home',
  'supplier',
  'veterinary_clinic',
  'other'
);

CREATE TABLE public.organization (
  id                SERIAL PRIMARY KEY,
  external_id       TEXT,
  name              TEXT,
  type              org_type,
  other_text        TEXT,
  CHECK (other_text IS NOT NULL OR type != 'other'),
  address_id        INTEGER REFERENCES public.address(id),
  email             TEXT,
  phone             TEXT,
  fax_number        TEXT,
  website_url       TEXT,
  notes             TEXT,
  updated_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by        INTEGER REFERENCES user_profile(id) NOT NULL,
  created_by        INTEGER REFERENCES user_profile(id) NOT NULL,
  created_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_time      TIMESTAMP WITH TIME ZONE,
  deleted_by        INTEGER REFERENCES user_profile(id),
  funeral_home_id   INTEGER REFERENCES funeral_home(id) NOT NULL,
  rank_in_org       INTEGER NOT NULL DEFAULT 0,
  teleflora_code    TEXT,
  exclusive_florist BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE UNIQUE INDEX organization_external_id ON public.organization (funeral_home_id, external_id);

ALTER TABLE public.entity ADD FOREIGN KEY (organization_id) REFERENCES organization(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX unique_entity_external_id ON public.entity (organization_id, external_id);

ALTER TABLE public.funeral_home ADD FOREIGN KEY (last_florist_id) REFERENCES organization(id) ON DELETE SET NULL;

CREATE TABLE user_session (
  id                    UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v1mc(),
  user_profile_id       INTEGER REFERENCES user_profile(id),
  token                 TEXT UNIQUE,
  token_expires         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  user_agent            TEXT,
  ip_address            TEXT,
  last_login            TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX user_session_user_profile_idx ON user_session(user_profile_id);

CREATE TYPE funeral_type AS ENUM ('burial', 'cremation', 'military', 'service');

CREATE TYPE case_type AS ENUM ('pre-need', 'at-need', 'trade', 'one-off');

CREATE TABLE public.death_certificate_config (
  id                       SERIAL PRIMARY KEY,
  name                     TEXT NOT NULL,
  funeral_home_id          INTEGER REFERENCES public.funeral_home(id),
  cloned_from              INTEGER NOT NULL REFERENCES public.death_certificate_config(id),
  created_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time             TIMESTAMP WITH TIME ZONE,
  deleted_by               INTEGER REFERENCES public.user_profile(id),
  imported_case_config     BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE public.funeral_home ADD COLUMN default_dc_config_id INTEGER NOT NULL REFERENCES public.death_certificate_config(id);

CREATE TABLE public.death_certificate_config_revision (
  id                       SERIAL PRIMARY KEY,
  config_id                INTEGER NOT NULL REFERENCES public.death_certificate_config(id),
  replaces                 INTEGER UNIQUE REFERENCES public.death_certificate_config_revision(id),
  cloned_from              INTEGER REFERENCES public.death_certificate_config_revision(id),
  created_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  imported_case_config     BOOLEAN NOT NULL DEFAULT FALSE
  CONSTRAINT must_clone_or_replace CHECK (cloned_from IS NOT NULL OR replaces IS NOT NULL)
);

CREATE TABLE public.death_certificate_config_field (
  ui_field_key             TEXT NOT NULL, -- key of the corresponding UI element
  config_rev_id            INTEGER NOT NULL REFERENCES public.death_certificate_config_revision(id),
  rank                     INTEGER NOT NULL DEFAULT 0,
  is_required              BOOLEAN NOT NULL,
  is_hidden_from_family    BOOLEAN NOT NULL,
  options                  TEXT[],
  label_override           TEXT,
  created_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  CONSTRAINT death_certificate_config_field_pkey PRIMARY KEY(ui_field_key, config_rev_id)
);

CREATE INDEX death_certificate_config_funeral_home_idx ON death_certificate_config(funeral_home_id);
CREATE INDEX death_certificate_config_rev_config_idx ON death_certificate_config_revision(config_id);
CREATE INDEX death_certificate_config_field_config_rev_idx ON death_certificate_config_field(config_rev_id);

CREATE TABLE public.theme (
  id                                 SERIAL PRIMARY KEY,
  rank                               INTEGER NOT NULL DEFAULT 0,
  name                               TEXT NOT NULL,
  description                        TEXT,
  thumbnail_view_id                  INTEGER REFERENCES public.photo_view(id),
  primary_color                      TEXT NOT NULL,
  secondary_color                    TEXT NOT NULL,
  primary_background_image_view_id   INTEGER REFERENCES public.photo_view(id),
  secondary_background_image_view_id INTEGER REFERENCES public.photo_view(id),
  top_accent_image_view_id           INTEGER REFERENCES public.photo_view(id),
  top_accent_image_reversed_view_id  INTEGER REFERENCES public.photo_view(id),
  top_graphic_view_id                INTEGER REFERENCES public.photo_view(id),
  top_mobile_graphic_view_id         INTEGER REFERENCES public.photo_view(id),
  bottom_left_graphic_view_id        INTEGER REFERENCES public.photo_view(id),
  bottom_right_graphic_view_id       INTEGER REFERENCES public.photo_view(id),
  bottom_mobile_graphic_view_id      INTEGER REFERENCES public.photo_view(id),
  is_live                            BOOLEAN NOT NULL DEFAULT FALSE,
  created_by                         INTEGER REFERENCES public.user_profile(id) NOT NULL,
  updated_by                         INTEGER REFERENCES public.user_profile(id) NOT NULL,
  created_time                       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time                       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
  -- themes will belong to a specific funeral home once users can create their own themes
  -- funeral_home_id               INTEGER REFERENCES public.funeral_home(id) NOT NULL
);

CREATE TABLE public.theme_tags (
   name                   TEXT NOT NULL,
   value                  TEXT NOT NULL,
   theme_id               INTEGER NOT NULL REFERENCES public.theme(id) ON DELETE CASCADE,
   UNIQUE (name, value, theme_id)
);

CREATE TABLE public.gather_case (
  id                       SERIAL PRIMARY KEY,
  -- name                     TEXT REFERENCES public.gather_case_name(name) UNIQUE NOT NULL, -- added later
  fname                    TEXT NOT NULL,
  mname                    TEXT,
  lname                    TEXT NOT NULL,
  suffix                   TEXT,
  display_fname            TEXT NOT NULL,
  display_full_name        TEXT NOT NULL,

  dob_date                 TEXT DEFAULT NULL,
  dod_start_date           TEXT DEFAULT NULL, -- really a DATE type but Massive converts DATE to a JS Date object
  dod_start_time           TEXT NOT NULL DEFAULT '',
  dod_start_tz             TEXT NOT NULL,
  dod_end_date             TEXT DEFAULT NULL,
  dod_end_time             TEXT NOT NULL DEFAULT '',
  dod_end_tz               TEXT NOT NULL DEFAULT '',
  dop_date                 TEXT DEFAULT NULL,
  dop_time                 TEXT NOT NULL DEFAULT '',
  dop_tz                   TEXT NOT NULL DEFAULT '',
  death_date_unknown       BOOLEAN NOT NULL DEFAULT FALSE,
  -- dc_informant             INTEGER REFERENCES public.case_entity(id), -- added later
  -- dc_spouse                INTEGER REFERENCES public.case_entity(id), -- added later
  -- dc_father                INTEGER REFERENCES public.case_entity(id), -- added later
  -- dc_mother                INTEGER REFERENCES public.case_entity(id), -- added later
  death_certificate        JSONB DEFAULT NULL,
  death_certificate_locked BOOLEAN NOT NULL DEFAULT FALSE,

  death_certificate_percentage INTEGER,
  dc_updated_by            INTEGER REFERENCES user_profile(id),
  dc_updated_time          TIMESTAMP WITH TIME ZONE,
  dc_config_rev_id         INTEGER NOT NULL REFERENCES public.death_certificate_config_revision(id),

  created_time                      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  funeral_home_id                   INTEGER REFERENCES funeral_home(id) NOT NULL,
  photo_view_id                     INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
  ogimage_override_photo_view_id    INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
  is_test                           BOOLEAN NOT NULL DEFAULT FALSE,
  deleted_time                      TIMESTAMP WITH TIME ZONE,

  casket_bearers           TEXT,
  honorary_casket_bearers  TEXT,
  casket_bearers_locked    BOOLEAN NOT NULL DEFAULT FALSE,

  service_details          TEXT,
  service_details_locked   BOOLEAN NOT NULL DEFAULT FALSE,
  service_template_id      INTEGER, -- Will become FK to service_template(id)

  has_old_photo_dir        BOOLEAN DEFAULT FALSE,  -- TODO: remove once all cases have been converted to new directory structure
  options                  JSONB NOT NULL,
  link_gofundme            TEXT,
  link_memorialvideo_youtube TEXT,
  link_memorialvideo_tukios TEXT,
  link_memorialvideo_vimeo TEXT,

  imported_time            TIMESTAMP WITH TIME ZONE,
  updated_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by               INTEGER REFERENCES user_profile(id) NOT NULL,
  created_by               INTEGER REFERENCES user_profile(id) NOT NULL,

  theme_id                 INTEGER REFERENCES public.theme(id),
  desktop_cover_view_id    INTEGER REFERENCES photo_view(id) ON DELETE SET NULL,
  mobile_cover_view_id     INTEGER REFERENCES photo_view(id) ON DELETE SET NULL, 
  new_memories_sms_last_sent_time TIMESTAMP WITH TIME ZONE,
  new_memories_email_last_sent_time TIMESTAMP WITH TIME ZONE,
  case_label_ids           INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],  -- denormalized case_label.id for this case
  -- last_move_task_id        INTEGER REFERENCES public.case_task(task_id), -- added later in schema
  florist_id               INTEGER
);

ALTER TABLE public.gather_case ADD FOREIGN KEY (florist_id) REFERENCES organization(id) ON DELETE SET NULL;

CREATE TABLE public.gather_case_name (
  name                     TEXT PRIMARY KEY,
  gather_case_id           INTEGER REFERENCES public.gather_case(id), -- should be NOT NULL but has an order of operations issue w/ gather_case.name FK
  created_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by               INTEGER NOT NULL REFERENCES public.user_profile(id)
);

ALTER TABLE gather_case ADD COLUMN name TEXT REFERENCES public.gather_case_name(name) UNIQUE NOT NULL;

CREATE TABLE public.funeral_home_case (
  id                       SERIAL PRIMARY KEY,
  uuid                     UUID UNIQUE NOT NULL DEFAULT extensions.gen_random_uuid(),
  funeral_home_id          INTEGER NOT NULL REFERENCES public.funeral_home(id),
  gather_case_id           INTEGER NOT NULL REFERENCES public.gather_case(id),
  case_number              TEXT,
  assignee_id              INTEGER NOT NULL REFERENCES user_profile(id),
  case_type                case_type NOT NULL DEFAULT 'at-need'::case_type,
  case_type_change_time    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  case_type_change_by      INTEGER NOT NULL REFERENCES user_profile(id),
  -- workflow_id           INTEGER REFERENCES workflow(id) ON DELETE SET NULL -- added later in schema
  expense_total            BIGINT NOT NULL DEFAULT 0,
  collected_total          BIGINT NOT NULL DEFAULT 0,
  proposed_total           BIGINT NOT NULL DEFAULT 0,
  tax_total                BIGINT NOT NULL DEFAULT 0,
  statement_adjustments_total BIGINT NOT NULL DEFAULT 0,
  merch_pretax_sales_total    BIGINT NOT NULL DEFAULT 0,
  proserve_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  cashadv_pretax_sales_total  BIGINT NOT NULL DEFAULT 0,
  care_of_loved_one_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  transportation_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  use_of_facilities_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  casket_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  urn_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  vault_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  cemetery_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  memorial_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  flowers_pretax_sales_total BIGINT NOT NULL DEFAULT 0,
  archived_time            TIMESTAMP WITH TIME ZONE,
  whiteboard_rank          INTEGER,
  created_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by               INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time             TIMESTAMP WITH TIME ZONE,
  deleted_by               INTEGER REFERENCES public.user_profile(id),
  task_total_count         INTEGER NOT NULL DEFAULT 0,
  task_completed_count     INTEGER NOT NULL DEFAULT 0,
  step_total_count         INTEGER NOT NULL DEFAULT 0,
  step_completed_count     INTEGER NOT NULL DEFAULT 0,
  hero_font                hero_font_type,
  font_updated_by          INTEGER REFERENCES public.user_profile(id),
  -- this is denormalized to track the most recent successful payment for this case. It is set by a trigger on the payment table
  -- latest_successful_payment_id INTEGER REFERENCES public.payment(id); -- added later in schema
  UNIQUE (funeral_home_id, gather_case_id)
);
CREATE INDEX funeral_home_case_funeral_home_id_idx ON funeral_home_case(funeral_home_id);
CREATE INDEX funeral_home_case_gather_case_id_idx ON funeral_home_case(gather_case_id);
CREATE INDEX funeral_home_case_case_number_idx ON funeral_home_case(case_number);
CREATE INDEX funeral_home_case_assignee_id_idx ON funeral_home_case(assignee_id);
CREATE INDEX funeral_home_case_case_type_idx ON funeral_home_case(case_type);
CREATE INDEX funeral_home_case_archived_deleted_time_idx
  ON funeral_home_case(archived_time, deleted_time)
  WHERE archived_time IS NULL AND deleted_time IS NULL
;
-- ran in QA and prod - 8/1/2024
CREATE INDEX funeral_home_case_case_type_change_time_idx ON funeral_home_case(case_type_change_time);

ALTER TABLE gather_case ADD CONSTRAINT dod_start_date_format_constraint  CHECK (dod_start_date ~ '[12]\d{3}-(0\d|1[012])-([012]\d|3[01])');
ALTER TABLE gather_case ADD CONSTRAINT dod_end_date_format_constraint  CHECK (dod_end_date ~ '[12]\d{3}-(0\d|1[012])-([012]\d|3[01])');
ALTER TABLE gather_case ADD CONSTRAINT dob_date_format_constraint  CHECK (dob_date ~ '[12]\d{3}-(0\d|1[012])-([012]\d|3[01])');
ALTER TABLE gather_case ADD CONSTRAINT dop_date_format_constraint  CHECK (dop_date ~ '[12]\d{3}-(0\d|1[012])-([012]\d|3[01])');

CREATE INDEX gather_case_created_time_idx
  ON gather_case(created_time);

CREATE INDEX gather_case_updated_time_idx ON gather_case(updated_time);

CREATE INDEX gather_case_funeral_home_idx ON gather_case(funeral_home_id);

CREATE INDEX gather_case_desktop_cover_view_idx ON gather_case(desktop_cover_view_id);
CREATE INDEX gather_case_mobile_cover_view_idx ON gather_case(mobile_cover_view_id);
CREATE INDEX gather_case_photo_view_idx ON gather_case(photo_view_id);
CREATE INDEX gather_case_dod_start_date_idx ON gather_case(dod_start_date);

CREATE INDEX gather_case_option_remember_page_idx ON gather_case((options->>'remember_page'));
CREATE INDEX gather_case_dc_updated_time_idx ON gather_case(dc_updated_time);

CREATE TABLE public.funeral_home_case_watcher (
  id                      SERIAL PRIMARY KEY,
  funeral_home_case_id    INTEGER NOT NULL REFERENCES public.funeral_home_case(id),
  user_profile_id         INTEGER NOT NULL REFERENCES public.user_profile(id),
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  UNIQUE (funeral_home_case_id, user_profile_id)
);

CREATE TYPE public.gather_case_log_action AS ENUM ('column_changed');
CREATE TABLE public.gather_case_log (
  id                      SERIAL PRIMARY KEY,
  gather_case_id          INTEGER NOT NULL REFERENCES public.gather_case(id),
  action_type             public.gather_case_log_action NOT NULL,
  column_name             TEXT NOT NULL, -- i.e. is_test
  old_value               TEXT NOT NULL, -- i.e. FALSE
  new_value               TEXT NOT NULL, -- i.e. TRUE
  note                    TEXT,
  action_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  action_by               INTEGER NOT NULL REFERENCES public.user_profile(id)
);

CREATE TYPE public.funeral_home_case_log_action AS ENUM ('column_changed');
CREATE TABLE public.funeral_home_case_log (
  id                      SERIAL PRIMARY KEY,
  funeral_home_case_id    INTEGER NOT NULL REFERENCES public.funeral_home_case(id),
  action_type             public.funeral_home_case_log_action NOT NULL,
  column_name             TEXT NOT NULL, -- i.e. case_type
  old_value               TEXT NOT NULL, -- i.e. pre-need
  new_value               TEXT NOT NULL, -- i.e. at-need
  note                    TEXT,
  action_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  action_by               INTEGER NOT NULL REFERENCES public.user_profile(id)
);

CREATE FUNCTION set_case_data_on_insert ()
    RETURNS trigger AS $set_case_data_on_insert$
DECLARE
    _rand TEXT ;
    _randLetters TEXT ;
    _targetDateStr TEXT;
    _deathMonth TEXT ;
    _deathMonthName TEXT ;
    _deathYear TEXT ;
    _deathDay TEXT ;
    _option1 TEXT ;
    _option2 TEXT ;
    _option3 TEXT ;
    _option4 TEXT ; 
    _option5 TEXT ;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- New cases always inherit default case options from their funeral home
        NEW.options := (SELECT default_case_options FROM public.funeral_home WHERE id = NEW.funeral_home_id LIMIT 1);
        NEW.display_full_name := CONCAT_WS(' ', NEW.fname, NEW.lname);
        NEW.display_fname := NEW.fname;
        IF NULLIF(BTRIM(NEW.name), '') IS NULL THEN
            _randLetters := (SELECT array_to_string(ARRAY(SELECT chr((97 + ROUND(RANDOM() * 25)) :: INTEGER) FROM GENERATE_SERIES(1,5)), ''));
            _targetDateStr := (SELECT COALESCE(NULLIF(NEW.dod_start_date,''), CURRENT_DATE::TEXT));
            _deathMonth := (SELECT SPLIT_PART(_targetDateStr, '-',2));
            _deathMonthName := (to_char(to_timestamp(_deathMonth::text, 'MM'),'TMmon'));
            _deathYear := (SELECT SPLIT_PART(_targetDateStr, '-',1));
            _deathDay := (SELECT SPLIT_PART(_targetDateStr, '-',3));
            _option1 := (SELECT REGEXP_REPLACE(REGEXP_REPLACE(LOWER(CONCAT(TRIM(NEW.fname), '-', TRIM(NEW.lname))), '[^[:alnum:]]+', '-', 'g'), '(^-+|-+$)', '', 'g'));
            _option2 := (SELECT LOWER(CONCAT(_option1, '-', _deathYear)));
            _option3 := (SELECT LOWER(CONCAT(_option1, '-', _deathMonthName, '-', _deathYear)));
            _option4 := (SELECT LOWER(CONCAT(_option1, '-', _deathMonthName, '-', _deathDay, '-', _deathYear)));
            _option5 := (SELECT LOWER(CONCAT(_option1, '-', _deathMonthName, '-', _deathDay, '-', _deathYear, '-', _randLetters)));
            
            NEW.name := (WITH sug AS ( SELECT unnest(ARRAY[ _option1, _option2, _option3, _option4, _option5]) as name)
                SELECT sug.name
                FROM sug
                LEFT JOIN public.gather_case_name AS case_name
                ON case_name.name = sug.name
                WHERE case_name.name IS NULL
                ORDER BY char_length(sug.name) ASC
                LIMIT 1);
        END IF;

        INSERT INTO public.gather_case_name (name, gather_case_id, created_by) VALUES
          (NEW.name, NULL, 0); -- Need to update gather_case_id AFTER case is created
    END IF;
    RETURN NEW;
END;
$set_case_data_on_insert$
LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER set_case_data_on_create_trig
BEFORE INSERT ON gather_case
FOR EACH ROW
EXECUTE PROCEDURE set_case_data_on_insert();

CREATE FUNCTION after_case_insert ()
    RETURNS trigger AS $after_case_insert$
BEGIN
    IF (TG_OP = 'INSERT') THEN
      UPDATE public.gather_case_name SET gather_case_id = NEW.id
      WHERE name = NEW.name;
    END IF;
    RETURN NEW;
END;
$after_case_insert$
LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER after_case_insert_trigger
AFTER INSERT ON gather_case
FOR EACH ROW
EXECUTE PROCEDURE after_case_insert();

CREATE FUNCTION update_gathercase_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_time = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER set_case_updated_time
BEFORE UPDATE ON gather_case
FOR EACH ROW
EXECUTE PROCEDURE update_gathercase_timestamp();

CREATE TYPE public.website_vendor AS ENUM ('gather', 'funeralone', 'cfs', 'funeralinnovations');

CREATE TABLE public.website (
  id                      SERIAL PRIMARY KEY,
  url                     TEXT NOT NULL,
  vendor                  website_vendor NOT NULL,
  token                   TEXT NOT NULL,
  ga4_measurement_id      TEXT,
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  launched_time           TIMESTAMP WITH TIME ZONE,
  deleted_time            TIMESTAMP WITH TIME ZONE,
  block_subscriptions     BOOLEAN NOT NULL DEFAULT FALSE,
  duda_site_name          TEXT,
  duda_thumbnail_url      TEXT,
  duda_published_time     TIMESTAMP WITH TIME ZONE,
  duda_preview_url        TEXT,
  CONSTRAINT              website_vendor_token UNIQUE (vendor, token)
);

CREATE INDEX idx_website_duda_site_name ON public.website(duda_site_name);

CREATE TABLE public.funeral_home_website (
    funeral_home_id     INTEGER NOT NULL references public.funeral_home(id),
    website_id          INTEGER NOT NULL references public.website(id)
);
CREATE INDEX idx_funeral_home_website_website_id ON public.funeral_home_website(website_id);

CREATE TABLE public.website_case_alias (
    website_id          INTEGER NOT NULL references public.website(id),
    alias               TEXT NOT NULL,
    search_alias        TEXT NOT NULL,
    gather_case_id      INTEGER NOT NULL references public.gather_case(id),
    canonical           BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT          website_id_alias UNIQUE (website_id, alias)
);
CREATE INDEX website_search_alias ON public.website_case_alias(website_id, search_alias);
CREATE INDEX website_case_alias_canonical_idx ON public.website_case_alias(canonical);
CREATE INDEX website_case_alias_gather_case_idx ON website_case_alias(gather_case_id);

CREATE FUNCTION update_website_search_alias()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_alias = LOWER(NEW.alias);
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER set_website_search_alias
BEFORE INSERT OR UPDATE ON public.website_case_alias
FOR EACH ROW
EXECUTE PROCEDURE update_website_search_alias();

CREATE TABLE public.website_role_map (
    role                TEXT PRIMARY KEY,
    display_name        TEXT NOT NULL,
    description         TEXT NOT NULL,
    permissions         TEXT[] NOT NULL
);

CREATE TABLE public.website_user (
    id                  SERIAL PRIMARY KEY,
    website_id          INTEGER NOT NULL references public.website(id),
    user_id             INTEGER NOT NULL references public.user_profile(id),
    website_role        TEXT NOT NULL references public.website_role_map(role),
    can_manage_users    BOOLEAN NOT NULL DEFAULT FALSE,
    updated_time        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_by          INTEGER NOT NULL references public.user_profile(id),
    CONSTRAINT          website_user_unique UNIQUE (website_id, user_id)
);

CREATE TABLE public.gather_case_sync (
  gather_case_id      INTEGER REFERENCES public.gather_case(id) NOT NULL,
  vendor              website_vendor NOT NULL,
  synced_time         TIMESTAMP WITH TIME ZONE,
  synced_by           INTEGER REFERENCES public.user_profile(id),
  is_auto             BOOLEAN NOT NULL DEFAULT FALSE,
  -- No referential integrity because this mirrors a column in a foreign API, and the local view might be deleted
  photo_view_id       INTEGER,
  error               TEXT,
  -- Obit Notification enter a timestamp when we launch a run later job to notify 
  -- that process should update the success timestamp on success 
  notification_attempt_timestamp TIMESTAMP WITH TIME ZONE,
  notification_sent_timestamp   TIMESTAMP WITH TIME ZONE,
  notification_success_timestamp   TIMESTAMP WITH TIME ZONE,

  CONSTRAINT gather_case_sync_pkey PRIMARY KEY (gather_case_id, vendor)
);

CREATE INDEX gather_case_sync_gather_case_idx ON gather_case_sync(gather_case_id);

CREATE TYPE bill_type AS ENUM ('livestream');
CREATE TABLE gather_case_bill (
  gather_case_id        INTEGER NOT NULL REFERENCES gather_case(id),
  type                  bill_type NOT NULL,
  note                  TEXT NOT NULL DEFAULT '',
  amount                INTEGER NOT NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by            INTEGER REFERENCES user_profile(id) NOT NULL,
  billed_time           TIMESTAMP WITH TIME ZONE,
  billed_by             INTEGER REFERENCES user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER REFERENCES user_profile(id) NOT NULL,
  stripe_invoice_item_id TEXT,
  CONSTRAINT gather_case_bill_pkey PRIMARY KEY(gather_case_id, type)
);

CREATE TYPE case_gift_photo_type AS ENUM ('gift', 'card');

-- case gift photos
CREATE TABLE case_gift_photo (
  uuid                  TEXT PRIMARY KEY, -- generated in the UI client
  gift_photo_id         INTEGER REFERENCES photo(id) ON DELETE SET NULL,
  card_photo_id         INTEGER REFERENCES photo(id) ON DELETE SET NULL,
  excluded              case_gift_photo_type,
  gather_case_id        INTEGER NOT NULL REFERENCES gather_case(id) ON DELETE CASCADE,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TYPE orientation AS ENUM ('landscape', 'portrait');

CREATE TABLE template (
  id                    SERIAL PRIMARY KEY,
  name                  TEXT,
  description           TEXT,
  paper_height          DECIMAL(5, 2) DEFAULT 11.0,
  paper_width           DECIMAL(5, 2) DEFAULT 8.5,
  paper_orientation     orientation DEFAULT 'landscape',
  folds                 INTEGER DEFAULT 1
);

CREATE TYPE paper_side AS ENUM ('front', 'back');

CREATE TABLE template_page (
  id                    SERIAL PRIMARY KEY,
  template_id           INTEGER REFERENCES template(id),
  page_number           INTEGER,
  name                  TEXT NOT NULL,
  paper_side            paper_side NOT NULL,
  design                JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE TYPE event_type AS ENUM ('arrangement', 'custom');
CREATE TYPE location_type AS ENUM ('funeral_home', 'event');

CREATE TABLE location (
  id                    SERIAL PRIMARY KEY,
  funeral_home_id       INTEGER NOT NULL REFERENCES funeral_home(id),
  name                  TEXT,
  address_id            INTEGER NOT NULL REFERENCES address(id),
  is_saved              BOOLEAN NOT NULL DEFAULT TRUE,
  location_type         location_type NOT NULL,
  created_by            INTEGER NOT NULL REFERENCES user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- these are cached customer-created events in their Google Calendar (i.e. personal appointments) 
CREATE TABLE google_event (
  id                    SERIAL PRIMARY KEY,
  google_calendar_id    INTEGER NOT NULL REFERENCES google_calendar(id) ON DELETE CASCADE,
  google_id             TEXT NOT NULL,
  name                  TEXT NOT NULL,
  description           TEXT,
  location              TEXT,
  start_datetime        TIMESTAMP WITH TIME ZONE,
  start_date            TEXT, -- using text so that the date string doesn't get converted to a Date object w/ timezone
  end_datetime          TIMESTAMP WITH TIME ZONE,
  end_date              TEXT, -- using text so that the date string doesn't get converted to a Date object w/ timezone
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  sync_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  url_to_event_in_gcal  TEXT,
  UNIQUE(google_id, google_calendar_id)
);

CREATE TABLE stream_log (
  id                    SERIAL PRIMARY KEY,
  event_id              TEXT NOT NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL,
  inserted_time         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  type                  TEXT NOT NULL, -- 'video.asset.created', 'video.live_stream.connected', etc
  object_id             TEXT NOT NULL,
  object_type           TEXT NOT NULL, -- 'live', 'asset', etc
  env_name              TEXT NOT NULL,
  env_id                TEXT NOT NULL,
  data                  JSONB NOT NULL
);

CREATE TABLE public.stream_device (
  id                    SERIAL PRIMARY KEY,
  nickname              TEXT NOT NULL,
  devicename            TEXT NOT NULL DEFAULT 'GatherCam-A',
  stream_key            TEXT NOT NULL, -- stream_key, stream_id, playback_id can be viewed on mux.com 
  stream_id             TEXT NOT NULL UNIQUE, 
  playback_id           TEXT NOT NULL,
  is_recording          BOOLEAN NOT NULL DEFAULT FALSE,
  recording_update_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  is_streaming          BOOLEAN NOT NULL DEFAULT FALSE,
  streaming_update_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by            INTEGER NOT NULL REFERENCES user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by            INTEGER REFERENCES user_profile(id),
  deleted_time          TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  stream_device_type    stream_device_type NOT NULL,
  sent_camera_left_streaming  TIMESTAMP WITH TIME ZONE,
  tablet_notes          TEXT, 
  camera_notes          TEXT
);
CREATE INDEX stream_device_nickname_idx ON stream_device (nickname);
CREATE INDEX stream_device_sent_camera_left_streaming_idx
  ON stream_device(sent_camera_left_streaming);

CREATE TABLE public.funeral_home_stream_device (
  funeral_home_id       INTEGER NOT NULL REFERENCES public.funeral_home(id),
  stream_device_id      INTEGER NOT NULL REFERENCES public.stream_device(id),
  PRIMARY KEY(funeral_home_id, stream_device_id)
);

CREATE TABLE public.event (
  id                    SERIAL PRIMARY KEY,
  name                  TEXT NOT NULL,
  description           TEXT,
  gather_case_id        INTEGER NOT NULL REFERENCES gather_case(id) ON DELETE CASCADE,
  location_id           INTEGER REFERENCES location(id) ON DELETE SET NULL,
  event_type            event_type NOT NULL,
  start_time            TIMESTAMP WITH TIME ZONE,
  hide_start_time       BOOLEAN NOT NULL DEFAULT FALSE,
  end_time              TIMESTAMP WITH TIME ZONE,
  hide_end_time         BOOLEAN NOT NULL DEFAULT FALSE,
  created_by            INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by            INTEGER REFERENCES user_profile(id),
  deleted_time          TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  visible_to_family     BOOLEAN NOT NULL DEFAULT TRUE,
  editable_by_family    BOOLEAN NOT NULL DEFAULT FALSE,
  gcal_event_id         TEXT,
  gcal_created_time     TIMESTAMP WITH TIME ZONE,
  gcal_create_attempt_time TIMESTAMP WITH TIME ZONE,
  stream_device_id      INTEGER REFERENCES stream_device(id),
  is_streamable         BOOLEAN NOT NULL DEFAULT FALSE, 
  broadcast_start_time  TIMESTAMP WITH TIME ZONE,
  broadcast_end_time    TIMESTAMP WITH TIME ZONE,
  message               TEXT,
  is_private            BOOLEAN NOT NULL DEFAULT FALSE,
  sent_broadcast_interrupted        TIMESTAMP WITH TIME ZONE,
  sent_livestream_reminder          TIMESTAMP WITH TIME ZONE,
  sent_livestream_not_started       TIMESTAMP WITH TIME ZONE,
  email_summary_daybefore_sent_time TIMESTAMP WITH TIME ZONE,
  sms_summary_daybefore_sent_time   TIMESTAMP WITH TIME ZONE,
  email_service_reminder_sent_time  TIMESTAMP WITH TIME ZONE,
  sms_service_reminder_sent_time    TIMESTAMP WITH TIME ZONE
);

CREATE INDEX event_sent_broadcast_interrupted_idx
  ON public.event(sent_broadcast_interrupted);
CREATE INDEX event_sent_livestream_reminder_idx
  ON public.event(sent_livestream_reminder);
CREATE INDEX event_sent_livestream_not_started_idx
  ON public.event(sent_livestream_not_started);
CREATE INDEX event_gather_case_id_idx ON public.event(gather_case_id);

CREATE INDEX event_multiple_idx ON public.event (gather_case_id, start_time, visible_to_family, is_private, sms_service_reminder_sent_time, email_service_reminder_sent_time);
CREATE INDEX event_start_time_idx ON public.event(start_time);

CREATE OR REPLACE FUNCTION update_gathercase_timestamp_for_event()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.gather_case SET updated_TIME = NOW() WHERE id = NEW.gather_case_id;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER set_case_updated_time_for_event
AFTER INSERT OR UPDATE ON public.event
FOR EACH ROW
EXECUTE PROCEDURE update_gathercase_timestamp_for_event();

CREATE TYPE master_status_type AS ENUM ('preparing', 'ready', 'deleted', 'errored', 'never');

CREATE TABLE stream_asset (
  id                    SERIAL PRIMARY KEY,
  asset_id              TEXT NOT NULL, -- MUX id
  live_stream_id        TEXT, 
  playback_id           TEXT,
  meta_data             JSONB NOT NULL DEFAULT '{}'::JSONB,
  asset_status          TEXT NOT NULL DEFAULT 'initialized',
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),  -- MUX created_at 
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by            INTEGER REFERENCES user_profile(id),
  deleted_time          TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  delete_attempt_time   TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  duration              FLOAT,
  event_id              INTEGER REFERENCES event(id),
  passthrough           TEXT,
  is_live               BOOLEAN NOT NULL DEFAULT FALSE,
  asset_rank            INTEGER,
  master_status         master_status_type NOT NULL DEFAULT 'never'::master_status_type,
  master_url            TEXT,
  master_request_time   TIMESTAMP WITH TIME ZONE,
  master_ready_time     TIMESTAMP WITH TIME ZONE
);
CREATE UNIQUE INDEX stream_asset_asset_id_ukey ON stream_asset (asset_id);
CREATE INDEX stream_asset_event_idx ON stream_asset(event_id);

-- Video Tables 

CREATE TYPE uploaded_status_type AS ENUM ('uploading', 'uploaded', 'preparing', 'ready', 'errored');

SELECT 'Creating uploaded_asset TABLE...' AS "status";
CREATE TABLE uploaded_asset (
  id                    SERIAL PRIMARY KEY,
  event_id              INTEGER REFERENCES event(id),
  unique_id             TEXT NOT NULL,
  path                  TEXT NOT NULL,
  url                   TEXT NOT NULL,
  location              TEXT NOT NULL, -- was thinking this would be S3 | 
  asset_status          uploaded_status_type NOT NULL DEFAULT 'uploading'::uploaded_status_type,
  uploaded_time         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  uploaded_by           INTEGER NOT NULL REFERENCES user_profile(id)
);

CREATE TABLE feature_config (
  feature               TEXT NOT NULL REFERENCES feature(key),
  funeral_home_id       INTEGER NOT NULL REFERENCES funeral_home(id),
  enabled               BOOLEAN NOT NULL DEFAULT FALSE,
  set_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  set_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CONSTRAINT funeral_config_pkey PRIMARY KEY(feature, funeral_home_id)
);

CREATE TABLE public.workflow ( -- used to be default_task_list
  id                    SERIAL PRIMARY KEY,
  name                  TEXT NOT NULL,
  case_type             case_type NOT NULL,
  created_by            INTEGER NOT NULL REFERENCES user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  cloned_from           INTEGER REFERENCES workflow(id) ON DELETE SET NULL,
  imported_case         BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE funeral_home_case ADD COLUMN workflow_id INTEGER REFERENCES workflow(id) ON DELETE SET NULL;

CREATE TYPE task_state AS ENUM ('incomplete', 'skipped', 'complete');
CREATE TYPE public.task_type AS ENUM ('checklist_task', 'tracking_step');
CREATE TYPE public.tracking_step_type AS ENUM ('normal', 'move', 'initialize', 'finalize');
CREATE TYPE public.task_template_type AS ENUM ('invite_helpers', 'death_certificate', 'schedule_services', 'upload_photos',
  'complete_obituary', 'freeze_credit', 'close_social_media', 'contact_social_security', 'cancel_online_accounts', 'cancel_phone_service',
  'forward_mail', 'arrangement_conference', 'unclaimed_property', 'life_insurance', 'service_details', 'casket_bearers', 'form_dd_214',
  'flowers_cards', 'goods_and_services', 'signature_packet', 'live_stream', 'profile_and_cover_photos', 'export_to_messenger',
  'funeral_reimbursement', 'build_photo_slideshow'
);

-- Task Location -- used by cases
-- Locations where Tasks take place
CREATE TABLE task_location (
  id                    SERIAL PRIMARY KEY,
  name                  TEXT NOT NULL,
  capacity              INTEGER,
  cover_photo_id        INTEGER REFERENCES public.photo(id) ON DELETE SET NULL,
  cover_fallback_url    TEXT,
  address_id            INTEGER REFERENCES public.address(id) ON DELETE SET NULL,
  is_3rd_party          BOOLEAN NOT NULL DEFAULT FALSE,
  created_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by            INTEGER REFERENCES public.user_profile(id),
  deleted_time          TIMESTAMP WITH TIME ZONE
);

-- Funeral Home Task Location -- used by FH Back office AND cases
-- the same task location can be associated with zero-to-many funeral homes
CREATE TABLE public.funeral_home_task_location (
  task_location_id          INTEGER NOT NULL REFERENCES public.task_location(id),
  funeral_home_id           INTEGER NOT NULL REFERENCES public.funeral_home(id),
  rank                      INTEGER NOT NULL,
  created_by                INTEGER NOT NULL REFERENCES public.user_profile(id),
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by                INTEGER REFERENCES public.user_profile(id),
  deleted_time              TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (task_location_id, funeral_home_id)
);
CREATE INDEX funeral_home_task_location_funeral_home_id_idx ON public.funeral_home_task_location(funeral_home_id);

-- Task -- used by FH back office AND cases
-- Referenced by workflow_task and case_task
CREATE TABLE task (
  id                    SERIAL PRIMARY KEY,
  type                  task_type NOT NULL,
  icon                  TEXT,
  title                 TEXT NOT NULL,
  past_tense_title      TEXT,
  subtitle              TEXT,
  description           TEXT,
  template_type         public.task_template_type, -- for checklist_task
  tracking_step_type    public.tracking_step_type, -- for tracking_step
  can_complete          BOOLEAN NOT NULL,
  can_skip              BOOLEAN NOT NULL,
  visible_to_family     BOOLEAN NOT NULL,
  can_reassign_by_family BOOLEAN NOT NULL,
  can_assign_multiple   BOOLEAN NOT NULL,
  is_after_care         BOOLEAN NOT NULL, -- for checklist_task
  feature               TEXT REFERENCES feature(key), -- for checklist_task
  created_by            INTEGER NOT NULL REFERENCES user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by            INTEGER REFERENCES public.user_profile(id),
  deleted_time          TIMESTAMP WITH TIME ZONE,
  from_task_id          INTEGER REFERENCES public.task(id) ON DELETE SET NULL,
  from_workflow_id      INTEGER REFERENCES public.workflow(id) ON DELETE SET NULL,
  CONSTRAINT type_required_for_tracking_steps CHECK (type != 'tracking_step' OR tracking_step_type IS NOT NULL)
);

-- Funeral Home Task -- used by FH Back office and cases
-- the same task can be associated with zero-to-many funeral homes
CREATE TABLE public.funeral_home_task (
  task_id                   INTEGER NOT NULL REFERENCES public.task(id),
  funeral_home_id           INTEGER NOT NULL REFERENCES public.funeral_home(id),
  rank                      INTEGER NOT NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by                INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_by                INTEGER REFERENCES public.user_profile(id),
  deleted_time              TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (task_id, funeral_home_id)
);
CREATE INDEX funeral_home_task_funeral_home_id_idx ON public.funeral_home_task(funeral_home_id);

-- Case Task -- used by CASE only
-- a Task can only be associated with a single case
-- Will always have an associated task, basically INHERITS from it
-- When workflow is selected on a case all public.task records are cloned and case_task records created to point to those new, cloned tasks
CREATE TABLE public.case_task (
  task_id                   INTEGER NOT NULL REFERENCES public.task(id) PRIMARY KEY,
  funeral_home_case_id      INTEGER NOT NULL REFERENCES public.funeral_home_case(id),
  task_location_id          INTEGER REFERENCES public.task_location(id),
  rank                      INTEGER NOT NULL,
  signature_s3_file_id      INTEGER REFERENCES public.s3_file(id),
  additional_sig_s3_file_id INTEGER REFERENCES public.s3_file(id),
  note                      TEXT,
  note_updated_by           INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  note_updated_time         TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  is_locked                 BOOLEAN, -- for checklist_task
  assigned_to_all_time      TIMESTAMP WITH TIME ZONE, -- for checklist_task
  assigned_to_all_by        INTEGER REFERENCES user_profile(id), -- for checklist_task
  event_id                  INTEGER REFERENCES event(id) ON DELETE SET NULL, -- for checklist_task
  exited_location_time      TIMESTAMP WITH TIME ZONE, -- special use case for "move" tracking_steps. Set when the case moves FROM this location to another location
  marked_complete_time      TIMESTAMP WITH TIME ZONE, -- typically when the task is completed. However, for "move" tracking_steps this is when the case ARRIVES in the location
  marked_complete_by        INTEGER REFERENCES public.user_profile(id),
  performed_by              INTEGER REFERENCES public.user_profile(id), -- for tracking_step
  skipped_time              TIMESTAMP WITH TIME ZONE,
  skipped_by                INTEGER REFERENCES user_profile(id),
  complete_by_time          TIMESTAMP WITH TIME ZONE,
  assigned_user_profile_ids INTEGER[] NOT NULL DEFAULT ARRAY[]::INTEGER[],  -- denormalized user_task.user_profile_id for this case_task
  resolved_time             TIMESTAMP WITH TIME ZONE GENERATED ALWAYS AS (
    CASE
      WHEN marked_complete_time IS NOT NULL THEN marked_complete_time
      WHEN skipped_time IS NOT NULL THEN skipped_time
      ELSE NULL
    END
  ) STORED
);
CREATE INDEX case_task_funeral_home_case_id_idx ON public.case_task(funeral_home_case_id);
CREATE INDEX case_task_resolved_time_idx ON public.case_task(resolved_time);
CREATE INDEX case_task_for_note_report_idx ON public.case_task(COALESCE(note_updated_time, marked_complete_time)) WHERE note IS NOT NULL;
CREATE INDEX case_task_with_note_idx ON public.case_task(task_id) WHERE note IS NOT NULL;
CREATE INDEX case_task_funeral_home_case_id_and_task_id_idx ON case_task(funeral_home_case_id, task_id);

-- add case_task-related FKs
ALTER TABLE gather_case ADD COLUMN last_move_task_id INTEGER REFERENCES public.case_task(task_id);
CREATE INDEX gather_case_last_move_task_id ON gather_case(last_move_task_id);

CREATE TYPE public.task_component_type AS ENUM (
  'paragraph',
  'case_confirmation',
  'who_performed',
  'checklist_questions',
  'text_questions',
  'multiple_choice_question',
  'file_upload',
  'note',
  'personal_belongings',
  'fine_print',
  'fingerprint',
  'location',
  'family_sharing',
  'signature',
  'additional_signature'
);

-- Task Component -- used by back office AND case
-- When a workflow is selected by a case all task_components will be cloned along with their parent tasks
CREATE TABLE public.task_component (
  id                    SERIAL PRIMARY KEY,
  type                  public.task_component_type NOT NULL,
  task_id               INTEGER NOT NULL REFERENCES public.task(id),
  cloned_from           INTEGER REFERENCES public.task_component(id),
  configuration         JSONB NOT NULL, -- varies based on type, contains questions AND answers (if on case)
  rank                  INTEGER NOT NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time          TIMESTAMP WITH TIME ZONE,
  deleted_by            INTEGER REFERENCES public.user_profile(id)
);
CREATE INDEX task_component_task_id_idx ON public.task_component(task_id);
CREATE INDEX task_component_updated_time_idx ON public.task_component(updated_time);
CREATE INDEX task_component_for_note_report_idx ON public.task_component(task_id)
  WHERE type = 'note'
    AND deleted_time IS NULL
    AND LENGTH(TRIM(configuration->>'answer')) > 0;

CREATE TABLE case_note (
  id              SERIAL PRIMARY KEY,
  gather_case_id  INTEGER REFERENCES gather_case(id) NOT NULL,
  note            TEXT NOT NULL,
  created_by      INTEGER REFERENCES user_profile(id) NOT NULL,
  created_time    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_by      INTEGER REFERENCES user_profile(id) NOT NULL,
  updated_time    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX case_note_gather_case_id_idx ON public.case_note(gather_case_id);
CREATE INDEX case_note_updated_time_idx ON public.case_note(updated_time);

-- Any family user that has been assigned a task
CREATE TABLE user_task (
  task_id               INTEGER NOT NULL REFERENCES case_task(task_id) ON DELETE CASCADE,
  user_profile_id       INTEGER NOT NULL REFERENCES user_profile(id) ON DELETE CASCADE,
  assigned_by           INTEGER NOT NULL REFERENCES user_profile(id),
  assigned_time         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CONSTRAINT user_task_pkey PRIMARY KEY(user_profile_id, task_id)
);

CREATE INDEX user_task_task_id_idx ON user_task(task_id);
CREATE TYPE album_type AS ENUM ('generic', 'case', 'slideshow', 'rememberPreview');
CREATE TYPE album_download_status AS ENUM ('started', 'pending', 'completed', 'failed');

-- create new table for albums
CREATE TABLE album (
  id                SERIAL PRIMARY KEY,
  gather_case_id    INTEGER NOT NULL REFERENCES gather_case(id) ON DELETE CASCADE,
  task_id           INTEGER REFERENCES case_task(task_id) ON DELETE CASCADE,
  type              album_type NOT NULL,
  download_url      TEXT,
  download_status   album_download_status DEFAULT NULL,
  download_started  TIMESTAMP WITH TIME ZONE,
  download_created  TIMESTAMP WITH TIME ZONE,
  download_expiry   TIMESTAMP WITH TIME ZONE,
  download_count    INTEGER NOT NULL DEFAULT 0,
  name              TEXT NOT NULL,
  created_by        INTEGER REFERENCES user_profile(id) NOT NULL,
  created_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by        INTEGER REFERENCES user_profile(id) NOT NULL,
  updated_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX album_gather_case_id_idx ON album(gather_case_id);
CREATE INDEX album_task_id_idx ON album(task_id);

-- create table for album entries
-- we have an id so we can update rank order in a more efficient way
CREATE TABLE album_entry (
  id                    SERIAL PRIMARY KEY,
  album_id              INTEGER NOT NULL REFERENCES album(id) ON DELETE CASCADE,
  photo_view_id         INTEGER NOT NULL REFERENCES photo_view(id) ON DELETE CASCADE,
  rank                  INTEGER NOT NULL,
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE(rank, album_id, photo_view_id)
);

CREATE INDEX album_entry_album_idx ON album_entry(album_id);
CREATE INDEX album_entry_photo_view_idx ON album_entry(photo_view_id);
CREATE INDEX album_entry_updated_time_idx ON album_entry(updated_time);

CREATE TABLE public.obituary (
  id                    SERIAL PRIMARY KEY,
  gather_case_id        INTEGER UNIQUE NOT NULL REFERENCES gather_case(id) ON DELETE CASCADE,
  content               TEXT NOT NULL,
  published_content     TEXT,
  updated_time          TIMESTAMP WITH TIME ZONE,
  updated_by            INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  approved_time         TIMESTAMP WITH TIME ZONE,
  approved_by           INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  locked                BOOLEAN NOT NULL DEFAULT FALSE,
  locked_by             INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  post_to_fh_website    BOOLEAN NOT NULL DEFAULT FALSE,
  place_in_newspaper    BOOLEAN NOT NULL DEFAULT FALSE,
  newspapers            JSONB,
  external_id           TEXT,
  auto_obit             JSONB,
  auto_obit_content     TEXT NOT NULL DEFAULT '',
  auto_obit_error       TEXT,
  auto_obit_time        TIMESTAMP WITH TIME ZONE,
  auto_obit_count       INTEGER NOT NULL DEFAULT 0
  --data_source         dataload.data_source
);

-- create new table for obituary links on remember page
CREATE TABLE obituary_link (
   id                SERIAL PRIMARY KEY,
   gather_case_id    INTEGER NOT NULL REFERENCES gather_case(id) ON DELETE CASCADE,
   url               TEXT NOT NULL,
   title             TEXT NOT NULL,
   description       TEXT,
   created_by        INTEGER REFERENCES user_profile(id) NOT NULL,
   created_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
   updated_by        INTEGER REFERENCES user_profile(id) NOT NULL,
   updated_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
   external_id       TEXT
   --data_source     dataload.data_source
);


CREATE TYPE use_preference AS ENUM ('user_primary','funeral_home','override');

CREATE TABLE user_funeral_home (
user_profile_id  INTEGER NOT NULL REFERENCES user_profile(id) ON DELETE CASCADE,
funeral_home_id  INTEGER NOT NULL REFERENCES funeral_home(id) ON DELETE CASCADE,
deactivated_by   INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
deactivated_time TIMESTAMP WITH TIME ZONE,
created_by       INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
created_time     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_by       INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
updated_time     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
use_email_pref    use_preference NOT NULL DEFAULT 'user_primary'::use_preference,
use_phone_pref    use_preference NOT NULL DEFAULT 'funeral_home'::use_preference,
visible_title     TEXT,
visible_email     TEXT,
visible_phone     TEXT,
permissions       JSONB NOT NULL DEFAULT '{}'::JSONB, -- This default is actually set by the trigger set_default_permissions()
PRIMARY KEY(user_profile_id, funeral_home_id),
CONSTRAINT visible_value_set_if_used CHECK (
      ((use_email_pref = 'override' AND visible_email IS NOT NULL ) OR (use_email_pref != 'override'))
      AND
      ((use_phone_pref = 'override' AND visible_phone IS NOT NULL ) OR (use_phone_pref != 'override'))
      )
);

CREATE FUNCTION set_default_permissions()
RETURNS trigger AS
$BODY$
DECLARE
  permissions JSONB;
BEGIN
    IF (TG_OP = 'INSERT' AND NEW.permissions IS NULL OR NEW.permissions = '{}'::JSONB ) THEN 
      SELECT default_permissions(NEW.funeral_home_id) INTO NEW.permissions;
    END IF;
 return NEW; 
END;
$BODY$ LANGUAGE plpgsql VOLATILE;
-- Add to the table. 
SELECT 'Updating set_default_permissions.' AS message;
DROP TRIGGER IF EXISTS set_default_permissions_trigger ON user_funeral_home;
CREATE TRIGGER set_default_permissions_trigger BEFORE INSERT ON user_funeral_home FOR EACH ROW 
WHEN (NEW.permissions IS NULL OR NEW.permissions = '{}'::JSONB)
EXECUTE PROCEDURE set_default_permissions();


-- START APP-2049
CREATE TYPE deep_link_type AS ENUM (
    'reset_password',
    'gather_admin',
    'funeral_home',
    'case',
    'task',
    'contract',
    'payment_receipt',
    'remember',
    'organize',
    'google_calendar',
    'my_websites',
    'remember_book'
);

CREATE TABLE deep_link (
  id              TEXT PRIMARY KEY,
  gather_case_id  INTEGER REFERENCES public.gather_case(id) ON DELETE CASCADE,
  funeral_home_id INTEGER REFERENCES public.funeral_home(id) ON DELETE CASCADE,
  user_id         INTEGER REFERENCES public.user_profile(id) ON DELETE CASCADE,
  task_id         INTEGER REFERENCES public.case_task(task_id) ON DELETE CASCADE,
  -- book_uuid       UUID REFERENCES book.book(uuid) ON DELETE CASCADE, -- added later
  link_type       deep_link_type NOT NULL,
  public_link     BOOLEAN NOT NULL DEFAULT FALSE,
  created_time    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  accessed_time   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX deep_link_gather_case_id_index ON deep_link(gather_case_id);
CREATE INDEX deep_link_funeral_home_id_index ON deep_link(funeral_home_id);
CREATE INDEX deep_link_user_id_index ON deep_link(user_id);
-- CREATE INDEX deep_link_book_uuid_index ON deep_link(book_uuid); -- added later

CREATE INDEX deep_link_type_index ON public.deep_link(link_type);

-- END APP-2049

-- START APP-493 Gather Ledger API tables and functions
-- See https://docs.google.com/document/d/1WefgT02qzTJ18TrZ889k1QfFvdz2IpawU4yImJPxf-c/edit#


CREATE FUNCTION sync_user_profile_email_phone_function() 
RETURNS trigger AS
$BODY$
DECLARE
  fullname TEXT;
  words TEXT[];
  spaces INTEGER;
BEGIN

    IF (TG_OP = 'UPDATE') THEN 
      IF (NEW.email IS DISTINCT FROM OLD.email AND NEW.phone IS DISTINCT FROM OLD.phone ) THEN
        UPDATE public.user_profile SET email = NEW.email, phone = NEW.phone WHERE entity_id = NEW.id;
      ELSIF (NEW.phone IS DISTINCT FROM OLD.phone ) THEN
        UPDATE public.user_profile SET phone = NEW.phone WHERE entity_id = NEW.id;
      ELSIF (NEW.email IS DISTINCT FROM OLD.email ) THEN
        UPDATE public.user_profile SET email = NEW.email WHERE entity_id = NEW.id;
      END IF;
    END IF;
 return NEW; 
END;
$BODY$ LANGUAGE plpgsql VOLATILE;
-- Add to the table. 
SELECT 'Updating sync_email_phone_trigger.' AS message;
DROP TRIGGER IF EXISTS sync_email_phone_trigger ON entity;
CREATE TRIGGER sync_email_phone_trigger AFTER UPDATE ON entity FOR EACH ROW 
WHEN (OLD.email IS DISTINCT FROM NEW.email OR OLD.phone IS DISTINCT FROM NEW.phone )
EXECUTE PROCEDURE sync_user_profile_email_phone_function();

CREATE TYPE case_role AS ENUM ('guest');
ALTER TYPE case_role ADD VALUE 'admin';
ALTER TYPE case_role ADD VALUE 'visitor';

CREATE TYPE entity_relation_type AS ENUM ('family','church','work','school', 'friend');
ALTER TYPE entity_relation_type ADD VALUE 'other';

CREATE TYPE entity_relationship AS ENUM (
  -- Significant other
  'husband','exhusband','wife','exwife','spouse','partner','domesticPartner','significantOther','fiance'
  -- Parent
  ,'father','stepFather','fatherInLaw','mother','stepMother','motherInLaw'--,'parent','guardian','fosterParent'
  -- Child
  ,'son','stepSon','sonInLaw','daughter','stepDaughter','daughterInLaw','child','stepChild'
  -- Sibling
  ,'brother','stepBrother','brotherInLaw','halfBrother','sister','stepSister','sisterInLaw','halfSister','sibling'
  -- GRANDPARENT
  ,'grandfather','stepGrandfather','grandfatherInLaw','greatGrandfather','grandmother','stepGrandmother','grandmotherInLaw','greatGrandmother','grandparent','greatGrandparent'
  -- GRANDCHILD
  ,'grandson','stepGrandson','grandsonInLaw','greatGrandson','granddaughter','stepGranddaughter','granddaughterInLaw','greatGranddaughter','grandchild','greatGrandchild'
  -- OTHER
  ,'uncle','stepUncle','uncleInLaw','greatUncle','aunt','stepAunt','auntInLaw','greatAunt','nephew','greatNephew','niece','greatNiece','cousin','secondCousin'
  );
ALTER TYPE entity_relationship ADD VALUE 'other';

SELECT 'Creating case_entity table' AS message;
-- Table: case_entity
-- 
CREATE TABLE public.case_entity (
  id                      SERIAL PRIMARY KEY,
  entity_id               INTEGER NOT NULL REFERENCES public.entity(id) ON DELETE CASCADE,
  gather_case_id          INTEGER NOT NULL REFERENCES public.gather_case(id),
  created_by              INTEGER NOT NULL REFERENCES public.user_profile(id) DEFAULT 0,
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  accepted_time           TIMESTAMP WITH TIME ZONE,
  relationship_type       entity_relation_type,
  relationship            entity_relationship,
  relationship_alias      TEXT,
  case_role               case_role NOT NULL DEFAULT 'guest'::case_role,
  has_accepted_startup    BOOLEAN NOT NULL DEFAULT FALSE,
  moderation_status       public.moderation_status NOT NULL DEFAULT 'pending',
  moderation_reason       TEXT,
  moderation_time         TIMESTAMP WITH TIME ZONE,
  moderated_by            INTEGER REFERENCES public.user_profile(id),
  moderation_required     BOOLEAN NOT NULL DEFAULT TRUE,
  can_view_tracking_steps BOOLEAN NOT NULL DEFAULT FALSE,
  can_view_belongings     BOOLEAN NOT NULL DEFAULT FALSE,
  partner_case_entity_id  INTEGER UNIQUE REFERENCES public.case_entity(id) ON DELETE SET NULL,
  deleted_time            TIMESTAMP WITH TIME ZONE, -- For future use - not set yet
  deleted_by              INTEGER REFERENCES public.user_profile(id), -- For future use - not set yet
  UNIQUE (entity_id, gather_case_id)
);

CREATE INDEX case_entity_moderation_status_idx ON case_entity(moderation_status);
CREATE INDEX case_entity_moderation_time_idx ON case_entity(moderation_time);
CREATE INDEX case_entity_created_time_idx ON case_entity(created_time);

CREATE FUNCTION get_case_entity_display_relationship(ce case_entity) RETURNS TEXT
AS $get_case_entity_display_relationship_function_definition$
DECLARE
  display_text TEXT;
BEGIN
  display_text =
    COALESCE(
      NULLIF(TRIM(INITCAP(ce.relationship_alias::TEXT)),''),
      NULLIF(TRIM(
        CASE ce.relationship
          WHEN 'husband' THEN 'Husband'
          WHEN 'exhusband' THEN 'Ex-Husband'
          WHEN 'wife' THEN 'Wife'
          WHEN 'exwife' THEN 'Ex-Wife'
          WHEN 'spouse' THEN 'Spouse'
          WHEN 'partner' THEN 'Partner'
          WHEN 'domesticPartner' THEN 'Domestic Partner'
          WHEN 'significantOther' THEN 'Significant Other'
          WHEN 'fiance' THEN 'Fiance'
          WHEN 'father' THEN 'Father'
          WHEN 'stepFather' THEN 'Step-Father'
          WHEN 'fatherInLaw' THEN 'Father-in-law'
          WHEN 'mother' THEN 'Mother'
          WHEN 'stepMother' THEN 'Step-Mother'
          WHEN 'motherInLaw' THEN 'Mother-in-law'
          WHEN 'son' THEN 'Son'
          WHEN 'stepSon' THEN 'Step-Son'
          WHEN 'sonInLaw' THEN 'Son-in-law'
          WHEN 'daughter' THEN 'Daughter'
          WHEN 'stepDaughter' THEN 'Step-Daughter'
          WHEN 'daughterInLaw' THEN 'Daughter-in-law'
          WHEN 'child' THEN 'Child'
          WHEN 'stepChild' THEN 'Step-Child'
          WHEN 'brother' THEN 'Brother'
          WHEN 'stepBrother' THEN 'Step-Brother'
          WHEN 'brotherInLaw' THEN 'Brother-in-law'
          WHEN 'halfBrother' THEN 'Half-Brother'
          WHEN 'sister' THEN 'Sister'
          WHEN 'stepSister' THEN 'Step-Sister'
          WHEN 'sisterInLaw' THEN 'Sister-in-law'
          WHEN 'halfSister' THEN 'Half-Sister'
          WHEN 'sibling' THEN 'Sibling'
          WHEN 'grandfather' THEN 'Grandfather'
          WHEN 'stepGrandfather' THEN 'Step-Grandfather'
          WHEN 'grandfatherInLaw' THEN 'Grandfather-in-law'
          WHEN 'greatGrandfather' THEN 'Great-Grandfather'
          WHEN 'grandmother' THEN 'Grandmother'
          WHEN 'stepGrandmother' THEN 'Step-Grandmother'
          WHEN 'grandmotherInLaw' THEN 'Grandmother-in-law'
          WHEN 'greatGrandmother' THEN 'Great-Grandmother'
          WHEN 'grandparent' THEN 'Grandparent'
          WHEN 'greatGrandparent' THEN 'Great Grandparent'
          WHEN 'grandson' THEN 'Grandson'
          WHEN 'stepGrandson' THEN 'Step-Grandson'
          WHEN 'grandsonInLaw' THEN 'Grandson-in-law'
          WHEN 'greatGrandson' THEN 'Great Grandson'
          WHEN 'granddaughter' THEN 'Granddaughter'
          WHEN 'stepGranddaughter' THEN 'Step-Granddaughter'
          WHEN 'granddaughterInLaw' THEN 'Granddaughter-in-law'
          WHEN 'greatGranddaughter' THEN 'Great Granddaughter'
          WHEN 'grandchild' THEN 'Grandchild'
          WHEN 'greatGrandchild' THEN 'Great Grandchild'
          WHEN 'uncle' THEN 'Uncle'
          WHEN 'stepUncle' THEN 'Step-Uncle'
          WHEN 'uncleInLaw' THEN 'Uncle-in-law'
          WHEN 'greatUncle' THEN 'Great Uncle'
          WHEN 'aunt' THEN 'Aunt'
          WHEN 'stepAunt' THEN 'Step-Aunt'
          WHEN 'auntInLaw' THEN 'Aunt-in-law'
          WHEN 'greatAunt' THEN 'Great Aunt'
          WHEN 'nephew' THEN 'Nephew'
          WHEN 'greatNephew' THEN 'Great Nephew'
          WHEN 'niece' THEN 'Niece'
          WHEN 'greatNiece' THEN 'Great Niece'
          WHEN 'cousin' THEN 'Cousin'
          WHEN 'secondCousin' THEN 'Second-Cousin'
        END
      ), ''),
      NULLIF(TRIM(
        CASE
          WHEN ce.relationship_type = 'family' THEN 'Family Member'
          WHEN ce.relationship_type = 'church' THEN 'Church Friend'
          WHEN ce.relationship_type = 'work'   THEN 'Co-Worker'
          WHEN ce.relationship_type = 'school' THEN 'Classmate'
          WHEN ce.relationship_type = 'friend' THEN 'Friend'
          WHEN ce.relationship_type = 'other'  THEN 'Not Specified'
        END
      ), '')
    );

    RETURN display_text;
END;
$get_case_entity_display_relationship_function_definition$
LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION get_case_death_datetime(date_str TEXT, time_str TEXT, tz TEXT) RETURNS TIMESTAMP WITH TIME ZONE
AS $get_case_death_datetime_function_definition$
BEGIN

  RETURN CASE WHEN NULLIF(date_str, '') IS NULL
        THEN NULL
        -- Assume time of death is Noon if not set, and assume FH timezone if timezone is not set
        ELSE (date_str::DATE + COALESCE(NULLIF(time_str, ''), '12:00')::TIME) AT TIME ZONE
            COALESCE(
                NULLIF(tz, ''),
                'America/Denver'
            )
  END;
END;
$get_case_death_datetime_function_definition$
LANGUAGE plpgsql IMMUTABLE;


CREATE TYPE memory_prompt AS ENUM (
    'Default',
    'Candle',
    'KnowPerson',
    'InterestingFact',
    'DescribePerson',
    'FunnyStory',
    'BetterPlace',
    'Legacy',
    'AlwaysRemember',
    'Admired',
    'FavoriteStory',
    'MadeSpecial',
    'HelpOthers',
    'TeachYou',
    'LoveAbout',
    'SayToday',
    'LovedToDo',
    'GoodAt',
    'MakeYouLaugh',
    'PossessionPlaceHoliday',
    'EarliestMemory',
    'Quotes',
    'FunniestQuirks',
    'ValueMost',
    'DescribeCharacter',
    'HundredYears'
);

CREATE TABLE public.memory (
  id                    SERIAL PRIMARY KEY,
  user_id               INTEGER NOT NULL REFERENCES public.user_profile(id),
  gather_case_id        INTEGER NOT NULL REFERENCES public.gather_case(id),
  memory_text           TEXT NOT NULL,
  prompt                memory_prompt NOT NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES user_profile(id),
  moderation_status     public.moderation_status NOT NULL DEFAULT 'pending',
  moderation_reason     TEXT,
  moderation_time       TIMESTAMP WITH TIME ZONE,
  moderated_by          INTEGER REFERENCES public.user_profile(id),
  moderation_required   BOOLEAN NOT NULL DEFAULT TRUE,
  imported_time         TIMESTAMP WITH TIME ZONE,
  external_id           TEXT -- Usually comes from scraped obit - use MD5 hash of text as the key
  -- data_source        dataload.data_source
);

CREATE INDEX memory_gather_case_id ON memory(gather_case_id);
CREATE INDEX memory_moderation_status_idx ON memory(moderation_status);
CREATE INDEX memory_created_time_idx ON memory(created_time);
CREATE INDEX memory_moderation_time_idx ON memory(moderation_time);

-- add case_entity FK references
ALTER TABLE gather_case
  ADD COLUMN dc_informant INTEGER REFERENCES public.case_entity(id),
  ADD COLUMN dc_spouse    INTEGER REFERENCES public.case_entity(id),
  ADD COLUMN dc_father    INTEGER REFERENCES public.case_entity(id),
  ADD COLUMN dc_mother    INTEGER REFERENCES public.case_entity(id)
;

CREATE INDEX case_entity_gather_case_idx ON case_entity(gather_case_id);

CREATE TABLE public.moderation_queue (
  id                    SERIAL PRIMARY KEY,
  case_entity_id        INTEGER NULL REFERENCES public.case_entity(id) ON DELETE CASCADE UNIQUE,
  photo_id              INTEGER NULL REFERENCES public.photo(id) ON DELETE CASCADE UNIQUE,
  memory_id             INTEGER NULL REFERENCES public.memory(id) ON DELETE CASCADE UNIQUE,
  -- Only one and exactly one of the FKs shall be set
  CONSTRAINT moderation_queue_fk_check
  CHECK (
    (
      (case_entity_id IS NOT NULL)::INTEGER
      + (photo_id IS NOT NULL)::INTEGER
      + (memory_id IS NOT NULL)::INTEGER
    ) = 1
  )
);

ALTER TABLE user_profile ADD CONSTRAINT user_profile_entity_id_fk FOREIGN KEY (entity_id) REFERENCES entity (id);

CREATE FUNCTION create_entity_on_insert() RETURNS trigger 
AS $create_entity_on_insert_function_definition$
DECLARE
   new_entity_id INTEGER;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF ( NEW.entity_id IS NULL ) THEN
            INSERT INTO entity (fname,lname,email,phone,type,home_address_id) 
            VALUES (
                NEW.fname, NEW.lname, NEW.email, NEW.phone, 'person'::entity_type, NEW.home_address_id
            ) RETURNING id INTO new_entity_id;
            UPDATE user_profile SET entity_id = new_entity_id WHERE id = NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END; 
$create_entity_on_insert_function_definition$
LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER user_profile_on_create_trig 
AFTER INSERT ON user_profile
FOR EACH ROW
EXECUTE PROCEDURE create_entity_on_insert();


CREATE SCHEMA IF NOT EXISTS ledger_staging;
CREATE SCHEMA IF NOT EXISTS ledger;

CREATE TYPE ledger.asset_type AS ENUM ('USD');

-- See https://stripe.com/docs/api/payouts/object
CREATE TYPE payout_status AS ENUM ('paid', 'pending', 'in_transit', 'canceled', 'failed');
CREATE TABLE public.payout (
  id                    TEXT PRIMARY KEY,
  funeral_home_id       INTEGER REFERENCES funeral_home(id),
  amount                BIGINT,
  arrival_date          TIMESTAMP WITH TIME ZONE,
  created               TIMESTAMP WITH TIME ZONE NOT NULL,
  updated               TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  asset_type            ledger.asset_type NOT NULL DEFAULT 'USD',
  failure_code          TEXT,
  failure_message       TEXT,
  status                payout_status NOT NULL,
  transactions          JSONB,
  count                 INTEGER NOT NULL DEFAULT 0
);

-- card means terminal payment with 'Card Present'
-- online mean 'Card Not Present'
CREATE TYPE payment_method AS ENUM ('unknown', 'check', 'cash', 'card', 'online', 'insurance', 'plaid', 'other', 'ach');
CREATE TYPE payment_mode AS ENUM ('in_person', 'remote', 'guest');
CREATE TYPE payment_status AS ENUM ('proposed', 'requested', 'pending', 'failed', 'succeeded', 'refunded', 'canceled');
CREATE TABLE public.payment (
  id                    SERIAL PRIMARY KEY,
  mode                  payment_mode NOT NULL DEFAULT 'in_person',
  payer                 INTEGER REFERENCES public.entity(id),
  is_anon               BOOLEAN NOT NULL DEFAULT FALSE,
  customer_id           INTEGER REFERENCES public.entity(id) NOT NULL,
  processor_id          INTEGER REFERENCES public.entity(id),
  funeral_home_case_id  INTEGER NOT NULL REFERENCES public.funeral_home_case(id),
  amount                BIGINT NOT NULL,
  asset_type            ledger.asset_type NOT NULL DEFAULT 'USD',
  created_by            INTEGER REFERENCES public.user_profile(id) NOT NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX payment_created_time_idx ON public.payment(created_time);
CREATE INDEX payment_funeral_home_case_id_idx ON public.payment(funeral_home_case_id);

ALTER TABLE funeral_home_case ADD COLUMN latest_successful_payment_id INTEGER REFERENCES public.payment(id);

-- get the most recent successful payment for this case and update the case with that payment id
CREATE OR REPLACE FUNCTION set_case_latest_successful_payment_id(_funeral_home_case_id INTEGER) RETURNS INTEGER
AS $set_case_latest_successful_payment_id$
DECLARE
  payment_id INTEGER;
BEGIN
  WITH payment AS (
    SELECT id FROM payment
    LEFT JOIN (
      WITH RankedPayments AS (
        SELECT
          pgp.payment_id,
          COALESCE(gp.payment_status, pgp.status) as status,
          COALESCE(gp.payment_time, pgp.created_time) as payment_time,
          ROW_NUMBER() OVER (PARTITION BY pgp.payment_id ORDER BY gp.id DESC) AS rn
        FROM payment_gather_payment pgp
        LEFT JOIN gather_payment gp
          ON gp.id = pgp.gather_payment_id
        JOIN payment p
          ON p.id = pgp.payment_id
          AND p.funeral_home_case_id = _funeral_home_case_id
        WHERE gp.payment_status in ('succeeded')
      )
      SELECT
        *
      FROM RankedPayments
      WHERE rn = 1
    ) as gather_payment
    on gather_payment.payment_id = payment.id
    WHERE funeral_home_case_id = _funeral_home_case_id
      AND gather_payment.status = 'succeeded'
    ORDER BY gather_payment.payment_time DESC, id DESC
    LIMIT 1
  ), updated_case AS (
    UPDATE funeral_home_case AS fhc
    SET latest_successful_payment_id = payment.id
    FROM payment
    WHERE fhc.id = _funeral_home_case_id
    RETURNING *
  )
  SELECT latest_successful_payment_id INTO payment_id
  FROM updated_case;
  RETURN payment_id;
END;
$set_case_latest_successful_payment_id$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_set_case_latest_successful_payment_id()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM set_case_latest_successful_payment_id(OLD.funeral_home_case_id);
    ELSE
        PERFORM set_case_latest_successful_payment_id(NEW.funeral_home_case_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_case_latest_successful_payment_id_trig
AFTER INSERT OR UPDATE OR DELETE ON public.payment
FOR EACH ROW
EXECUTE FUNCTION trigger_set_case_latest_successful_payment_id();

CREATE TYPE invoice_status AS ENUM ('draft', 'submitted', 'paid', 'void');
CREATE TABLE public.invoice (
    id                  SERIAL PRIMARY KEY,
    status              invoice_status NOT NULL DEFAULT 'draft',
    customer_id         INTEGER REFERENCES public.entity(id) NOT NULL,
    funeral_home_case_id INTEGER NOT NULL REFERENCES public.funeral_home_case(id),
    payment_id          INTEGER REFERENCES public.payment(id) ON DELETE SET NULL,
    -- product_id          INTEGER REFERENCES product.product(id) ON DELETE SET NULL, -- added later in schema
    -- product_category    product.category, -- added later in schema
    -- tax_rate_id         INTEGER REFERENCES product.tax_rate(id) ON DELETE SET NULL, -- added later in schema
    description         TEXT NOT NULL,
    issue_date          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    due_date            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    amount_due          BIGINT NOT NULL,
    sales_tax           BIGINT NOT NULL DEFAULT 0,
    is_fee              BOOLEAN NOT NULL DEFAULT FALSE,
    asset_type          ledger.asset_type NOT NULL DEFAULT 'USD',    
    reference           TEXT,
    memo                TEXT
);

--APP 4017
CREATE TABLE stripe_webhook_log (
  -- Event Level Details
  event_id              TEXT PRIMARY KEY,
  event_type            TEXT NOT NULL,
  account_id            TEXT,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL,
  -- Object Level Details
  object_id            TEXT,
  object_type          TEXT,
  object_amount        BIGINT,
  object_amount_refunded BIGINT,
  object_charge_id     TEXT,
  object_payment_method_id TEXT,
  object_failure_code  TEXT,
  object_failure_message TEXT,
  object_paid          BOOLEAN,
  object_customer_id   TEXT,
  object_description   TEXT,
  object_status        TEXT,
  object_name          TEXT,
  object_data          JSONB NOT NULL
);
CREATE INDEX stripe_webhook_log_event_type_idx ON stripe_webhook_log (event_type);
CREATE INDEX stripe_webhook_log_created_time_idx ON stripe_webhook_log (created_time);
--END APP 4017

-- invoice_funeral_home_case_id_idx ran in QA and prod - 7/30/2024
CREATE INDEX invoice_funeral_home_case_id_idx ON public.invoice(funeral_home_case_id);
CREATE INDEX invoice_issue_date_idx ON public.invoice(issue_date);

CREATE TYPE fee_type AS ENUM ('platform', 'merchant', 'processor');
CREATE TABLE fee (
  funeral_home_id       INTEGER REFERENCES public.funeral_home(id) NULL,
  method                payment_method NOT NULL,
  type                  fee_type NOT NULL,
  base                  BIGINT NOT NULL DEFAULT 0,
  rate                  DECIMAL(7, 4) DEFAULT 0.0,
  max                   BIGINT,
  PRIMARY KEY           (method, type, funeral_home_id)
);

CREATE TABLE default_fee (
  method                payment_method NOT NULL,
  type                  fee_type NOT NULL,
  base                  BIGINT NOT NULL DEFAULT 0,
  rate                  DECIMAL(12, 10) DEFAULT 0.0, -- already 12, 10 in dev/qa
  max                   BIGINT,
  PRIMARY KEY           (method, type)
);

CREATE OR  REPLACE FUNCTION fee_schedule(pfuneral_home_id INTEGER)
  RETURNS JSONB
AS $$
  WITH types AS (SELECT UNNEST(ENUM_RANGE(NULL::fee_type)) AS type),
  methods AS (SELECT UNNEST(ENUM_RANGE(NULL::payment_method)) AS method),
  fees AS (SELECT methods.method,
    JSONB_OBJECT_AGG(types.type, 
      JSONB_BUILD_OBJECT(
        'base', COALESCE(fee.base, defaults.base, 0::BIGINT),
        'rate', COALESCE(fee.rate, defaults.rate, 0.00::DECIMAL(7, 4)),
        'max', COALESCE(fee.max, defaults.max),
        'src', CASE
          WHEN fee.rate IS NOT NULL THEN 'F'
          WHEN defaults.rate IS NOT NULL THEN 'G'
          ELSE 'N'
        END
      )) AS fees
      FROM funeral_home fh
      CROSS JOIN  methods
      CROSS JOIN types
      LEFT JOIN default_fee AS defaults
        ON defaults.method = methods.method
          AND defaults.type = types.type
      LEFT JOIN fee
        ON fee.method = methods.method
          AND fee.type = types.type
          AND fee.funeral_home_id = fh.id
      WHERE fh.id = pfuneral_home_id
      GROUP BY methods.method)
  SELECT JSONB_OBJECT_AGG(fees.method, fees.fees) AS fee_schedule FROM fees;
$$ LANGUAGE SQL;

CREATE TABLE agreement (
  id                    SERIAL PRIMARY KEY,
  content               TEXT NOT NULL,
  is_master             BOOLEAN NOT NULL DEFAULT TRUE,
  created_by            INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION get_master_agreement() RETURNS INTEGER AS $get_master_agreement$
  DECLARE
    agreement_id INTEGER;
  BEGIN
      SELECT id INTO agreement_id
      FROM agreement
      WHERE is_master = TRUE
      ORDER BY id DESC
      LIMIT 1;
    RETURN agreement_id;
  END;
$get_master_agreement$ LANGUAGE plpgsql;

CREATE TABLE funeral_home_demo_settings (
  id   INTEGER NOT NULL REFERENCES funeral_home(id) ON DELETE CASCADE,
  -- Onboarding fee, in cents. Should not be set if ob_fee_waived = TRUE

  ob_fee            BIGINT,
  ob_fee_memo       TEXT NOT NULL DEFAULT '',
  -- Onboarding fee is waived, funeral home can sign up without paying
  ob_fee_waived     BOOLEAN NOT NULL DEFAULT FALSE,
  -- Payment status of the onboarding fee
  ob_fee_status     payment_status NOT NULL DEFAULT 'proposed',
  -- Payment method of the onboarding fee
  ob_fee_method     payment_method NOT NULL DEFAULT 'unknown',
  ob_items          TEXT NOT NULL DEFAULT E'Full Account Setup\nLogos and Brand Colors Loaded\nRemember Pages\nStandard + Custom Reports\nUnlimited Training\nUnlimited Customer Support\nDedicated Account Manager\nOngoing Updates + Data Security',
  calendly_url      TEXT NOT NULL DEFAULT '',
  -- Monthly fee, in cents
  monthly_fee       BIGINT,
  -- Show the "Get Started" option on the FH screen
  show_get_started  BOOLEAN NOT NULL DEFAULT FALSE,
  show_rep_message  BOOLEAN NOT NULL DEFAULT TRUE,
  rep_id            INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  rep_phone         TEXT NOT NULL DEFAULT '', -- Will pull this from the rep's user_profile when set
  rep_message       TEXT NOT NULL DEFAULT 'Welcome to Gather! We''re excited to work with you and give you a world-class, easy-to-use solution that helps both you as the funeral home and the families you serve. Feel free to contact me if you have any questions. Enjoy!',
  show_ob_message   BOOLEAN NOT NULL DEFAULT TRUE,
  ob_id             INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  ob_phone          TEXT NOT NULL DEFAULT '2089080488',
  ob_message        TEXT NOT NULL DEFAULT 'Welcome to your Gather account! I am your personal Success Manager. I will assist with your account set up and be here for ongoing support and training. Let me take care of the heavy lifting so you can continue to focus on your families. If you ever need support, you can call, click on the button in the bottom right-hand corner of your Gather account, or email our support team at help@gather.app.',
  agreement_id      INTEGER REFERENCES agreement(id) NOT NULL DEFAULT get_master_agreement(),
  agreement_waived  BOOLEAN NOT NULL DEFAULT FALSE,
  agreement_notes   TEXT NOT NULL DEFAULT '',
  agreed_by         INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  agreed_time       TIMESTAMP WITH TIME ZONE,
  agreed_ip_addr    TEXT,
  agreed_user_agent TEXT,
  est_case_volume   INTEGER,
  fh_notes          TEXT,
  UNIQUE (id)
);

CREATE OR REPLACE VIEW funeral_home_demo_settings_ux AS
SELECT ds.*,
  agreement.is_master,
  agreement.content AS agreement_content,
  rep_user_entity.fname AS rep_fname,
  rep_user_entity.lname AS rep_lname,
  rep_p.public_id AS rep_photo,
  rep_pv.transformations AS rep_transformations,
  ob_user_entity.fname AS ob_fname,
  ob_user_entity.lname AS ob_lname,
  ob_p.public_id AS ob_photo,
  ob_pv.transformations AS ob_transformations
FROM funeral_home_demo_settings AS ds
JOIN agreement
  ON agreement.id = ds.agreement_id
LEFT JOIN user_profile AS rep_user
  ON rep_user.id = ds.rep_id
LEFT JOIN entity AS rep_user_entity
  ON rep_user.entity_id = rep_user_entity.id
LEFT JOIN photo_view AS rep_pv
  ON rep_pv.id = rep_user_entity.photo_view_id
LEFT JOIN photo AS rep_p
  ON rep_p.id = rep_pv.photo_id
LEFT JOIN user_profile AS ob_user
  ON ob_user.id = ds.ob_id
LEFT JOIN entity AS ob_user_entity
  ON ob_user.entity_id = ob_user_entity.id
LEFT JOIN photo_view AS ob_pv
  ON ob_pv.id = ob_user_entity.photo_view_id
LEFT JOIN photo AS ob_p
  ON ob_p.id = ob_pv.photo_id
;

--APP-4029 Central DB Table for all Payment Types
--https://gatherly.atlassian.net/browse/APP-4029
CREATE TYPE payment_service AS ENUM ('STRIPE');
CREATE TABLE gather_payment(
  id SERIAL PRIMARY KEY,
  payment_service payment_service NOT NULL,
  payment_id TEXT NOT NULL,
  payment_method payment_method NOT NULL,
  payment_method_label TEXT,
  payment_status payment_status NOT NULL,
  payment_status_message TEXT,
  payment_amount BIGINT NOT NULL,
  asset_type ledger.asset_type NOT NULL DEFAULT 'USD',
  created_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  payment_time TIMESTAMP WITH TIME ZONE,
  updated_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX gather_payment_payment_id_payment_service_key 
ON gather_payment (payment_id, payment_service) 
WHERE payment_status = 'succeeded';

CREATE TABLE funeral_home_demo_settings_payment(
  id SERIAL PRIMARY KEY,
  funeral_home_demo_settings_id INTEGER REFERENCES funeral_home_demo_settings(id) NOT NULL,
  gather_payment_id INTEGER REFERENCES gather_payment(id) ON DELETE CASCADE NOT NULL,
  updated_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE (funeral_home_demo_settings_id, gather_payment_id)
);

CREATE TABLE payment_gather_payment(
  id SERIAL PRIMARY KEY,
  payment_id INTEGER REFERENCES public.payment(id) ON DELETE CASCADE NOT NULL,
  gather_payment_id INTEGER REFERENCES gather_payment(id) ON DELETE CASCADE,
  updated_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  status payment_status,
  error TEXT,
  app_fee BIGINT,
  proc_fee BIGINT,
  merch_fee BIGINT,
  amount BIGINT,
  asset_type ledger.asset_type,
  method payment_method,
  created_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  
  payment_time TIMESTAMP WITH TIME ZONE,  
  memo TEXT,
  canceled_time TIMESTAMP WITH TIME ZONE, 
  reconciled_time TIMESTAMP WITH TIME ZONE, 
  payout_id text,
  stripe_payment text,
  external_id text,
  source_id text,
  UNIQUE (payment_id, gather_payment_id)
);

CREATE INDEX payment_gather_payment_payment_id_idx ON payment_gather_payment(payment_id);

CREATE TYPE payment_entities AS ENUM ('onboarding', 'case', 'product');
CREATE TABLE gather_payment_entity(
  id SERIAL PRIMARY KEY,
  gather_payment_id INTEGER REFERENCES gather_payment(id) ON DELETE CASCADE NOT NULL,
  entity payment_entities NOT NULL,
  UNIQUE (gather_payment_id, entity)
);
-- END APP-4029 Central DB Table for all Payment Types

CREATE TYPE ledger.owner_type AS ENUM ('GATHER', 'FH');

CREATE TABLE ledger.extract (
  id                    SERIAL PRIMARY KEY,
  owner                 ledger.owner_type NOT NULL,
  funeral_home_id       INTEGER REFERENCES public.funeral_home(id),
  created_by            INTEGER REFERENCES public.user_profile(id) NOT NULL,
  extract_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  type                  TEXT NOT NULL,
  CONSTRAINT valid_ledger_extract CHECK (
      (funeral_home_id IS NULL AND owner = 'GATHER') OR
      (funeral_home_id IS NOT NULL AND owner = 'FH'))
);

CREATE TABLE ledger_staging.batch (
  id                    SERIAL PRIMARY KEY,
  created_by            INTEGER REFERENCES public.user_profile(id) NOT NULL,  
  purpose               TEXT NOT NULL,  
  open_time             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE ledger.batch (
  id                    SERIAL PRIMARY KEY,
  created_by            INTEGER REFERENCES public.user_profile(id) NOT NULL,  
  purpose               TEXT NOT NULL,  
  insert_time           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  stage_id              INTEGER
);
CREATE INDEX ON ledger.batch (stage_id);

CREATE TABLE ledger_staging.journal (
    id                  SERIAL PRIMARY KEY,
    batch_id            INTEGER REFERENCES ledger_staging.batch(id) ON DELETE CASCADE NOT NULL ,
    type                TEXT NOT NULL,
    description         TEXT NOT NULL,
    period              CHAR(7) NOT NULL DEFAULT TO_CHAR(NOW(), 'YYYY-MM'),
    funeral_home_case_id INTEGER NOT NULL REFERENCES public.funeral_home_case(id),
    invoice_id          INTEGER REFERENCES public.invoice(id),
    pgp_id              INTEGER REFERENCES payment_gather_payment(id) ON DELETE CASCADE,
    batch_invoice_number TEXT,
    batch_invoice_number_condensed TEXT
    -- this column is added after product.contract_revision is created, further down in this file
    -- revision_id         INTEGER REFERENCES product.contract_revision(id) ON DELETE SET NULL
);

CREATE TABLE ledger.journal (
    id                  SERIAL PRIMARY KEY,
    batch_id            INTEGER REFERENCES ledger.batch(id) NOT NULL,
    type                TEXT NOT NULL,
    description         TEXT NOT NULL,
    period              CHAR(7) NOT NULL,
    funeral_home_case_id INTEGER NOT NULL REFERENCES public.funeral_home_case(id),
    invoice_id          INTEGER REFERENCES public.invoice(id),
    pgp_id              INTEGER REFERENCES payment_gather_payment(id),
    entered_time        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    stage_id            INTEGER,
    reversed_by         INTEGER REFERENCES public.user_profile(id),
    reversed_time       TIMESTAMP WITH TIME ZONE,
    reversed_reason     TEXT,
    batch_invoice_number TEXT,
    batch_invoice_number_condensed TEXT
    -- this column is added after product.contract_revision is created, further down in this file
    -- revision_id         INTEGER REFERENCES product.contract_revision(id) ON DELETE SET NULL,
);
CREATE INDEX ON ledger.journal (stage_id);
CREATE INDEX journal_funeral_home_case_id_idx ON ledger.journal(funeral_home_case_id);
CREATE INDEX journal_invoice_id_idx ON ledger.journal(invoice_id);
CREATE INDEX journal_pgp_id_idx ON ledger.journal(pgp_id);

CREATE TYPE ledger.account_type AS ENUM ('assets', 'bank', 'expense', 'income', 'liability');

CREATE TABLE ledger.account (
    code                INTEGER NOT NULL PRIMARY KEY,
    name                TEXT NOT NULL,
    type                ledger.account_type NOT NULL,
    UNIQUE (name, type)
);

ALTER TABLE ledger.extract ADD COLUMN account INTEGER references ledger.account(code) NOT NULL;

CREATE TABLE ledger_staging.posting (
    id                  SERIAL PRIMARY KEY,
    journal_id          INTEGER REFERENCES ledger_staging.journal(id) ON DELETE CASCADE NOT NULL,
    owner               ledger.owner_type NOT NULL,
    account             INTEGER REFERENCES ledger.account(code) NOT NULL,
    customer_id         INTEGER REFERENCES public.entity(id),
    vendor_id           INTEGER REFERENCES public.entity(id),
    asset_type          ledger.asset_type NOT NULL DEFAULT 'USD',
    debit               BIGINT,
    credit              BIGINT,
    memo                TEXT NOT NULL,
    is_tax              BOOLEAN NOT NULL DEFAULT FALSE,
    is_fee              BOOLEAN NOT NULL DEFAULT FALSE,
    is_reversal         BOOLEAN NOT NULL DEFAULT FALSE,
    contract_item_id    TEXT,
    external_id         TEXT,
    CONSTRAINT valid_debit_credit CHECK (
        (COALESCE(debit > 0, FALSE) AND credit IS NULL) OR
        (COALESCE(credit > 0, FALSE) AND debit IS NULL) )
);

CREATE TABLE ledger.posting (
    id                  SERIAL PRIMARY KEY,
    journal_id          INTEGER REFERENCES ledger.journal(id) NOT NULL,
    owner               ledger.owner_type NOT NULL,
    account             INTEGER REFERENCES ledger.account(code) NOT NULL,
    customer_id         INTEGER REFERENCES public.entity(id),
    vendor_id           INTEGER REFERENCES public.entity(id),
    asset_type          ledger.asset_type NOT NULL DEFAULT 'USD',
    debit               BIGINT,
    credit              BIGINT,
    memo                TEXT NOT NULL,
    is_tax              BOOLEAN NOT NULL DEFAULT FALSE,
    is_fee              BOOLEAN NOT NULL DEFAULT FALSE,
    is_reversal         BOOLEAN NOT NULL DEFAULT FALSE,
    contract_item_id    TEXT,
    external_id         TEXT,
    cleared             TIMESTAMP WITH TIME ZONE,
    cleared_by          TEXT,
    extract_id          INTEGER REFERENCES ledger.extract(id) ON DELETE SET NULL
);

CREATE INDEX ON ledger.posting (owner);
CREATE INDEX ON ledger.posting(extract_id);
CREATE INDEX ON ledger.posting(external_id);
CREATE INDEX ON ledger.posting(journal_id);

CREATE FUNCTION ledger.validate_batch (_batch_id INTEGER)
    RETURNS TABLE (message TEXT, trace JSONB)
AS $$
BEGIN
--  Rule #1:
RETURN QUERY
SELECT
    'Debits and credits MUST balance when grouped by journal, owner, asset_type, and is_tax' AS message,
    JSONB_BUILD_OBJECT(
        'journal_id', j.id,
        'description', j.description,
        'owner', p.owner,
        'asset_type', p.asset_type,
        'debits', SUM(p.debit),
        'credits', SUM(p.credit),
        'total_postings', COUNT(p.id),
        'is_tax', p.is_tax
    ) AS trace
FROM ledger_staging.batch b
JOIN ledger_staging.journal j ON j.batch_id = b.id
JOIN ledger_staging.posting p ON p.journal_id = j.id
WHERE b.id = _batch_id
GROUP BY
    j.id, j.description, p.owner, p.asset_type, p.is_tax
HAVING COUNT(p.debit) = 0 OR COUNT(p.credit) = 0 OR SUM(p.debit) != SUM(p.credit)

-- Rule #2:
UNION SELECT
    'Postings to Assets:A/R and Income:Sales must reference a customer' AS message,
    JSONB_BUILD_OBJECT(
        'journal_id', j.id,
        'description', j.description,
        'posting_id', p.id,
        'memo', p.memo
    ) AS trace
FROM ledger_staging.batch b
JOIN ledger_staging.journal j ON j.batch_id = b.id
JOIN ledger_staging.posting p ON p.journal_id = j.id
JOIN ledger.account a ON a.code = p.account
WHERE b.id = _batch_id AND
    p.account IN (1200, 4020) AND p.customer_id IS NULL

-- Rule #3:
UNION SELECT
    'Postings to Expense accounts must reference a vendor' AS message,
    JSONB_BUILD_OBJECT(
        'journal_id', j.id,
        'description', j.description,
        'posting_id', p.id,
        'memo', p.memo
    ) AS trace
FROM ledger_staging.batch b
JOIN ledger_staging.journal j ON j.batch_id = b.id
JOIN ledger_staging.posting p ON p.journal_id = j.id
JOIN ledger.account a ON a.code = p.account
WHERE b.id = _batch_id AND
    a.type = 'expense' AND p.vendor_id IS NULL

-- Rule #4:
UNION SELECT
    'Postings to Income:Sales must reference an invoice' AS message,
    JSONB_BUILD_OBJECT(
        'journal_id', j.id,
        'description', j.description,
        'posting_id', p.id,
        'memo', p.memo
    ) AS trace
FROM ledger_staging.batch b
JOIN ledger_staging.journal j ON j.batch_id = b.id
JOIN ledger_staging.posting p ON p.journal_id = j.id
WHERE b.id = _batch_id AND
    p.account = 4020 AND j.invoice_id IS NULL

-- Rule #5:
UNION SELECT
    'Account owner must be FH for Bank:Trust and Bank:Funeral Home postings' AS message,
    JSONB_BUILD_OBJECT(
        'journal_id', j.id,
        'description', j.description,
        'posting_id', p.id,        
        'owner', p.owner
    ) AS trace
FROM ledger_staging.batch b
JOIN ledger_staging.journal j ON j.batch_id = b.id
JOIN ledger_staging.posting p ON p.journal_id = j.id
WHERE b.id = _batch_id AND
    p.account IN (1010, 1011) AND p.owner != 'FH'

-- Rule #6:
UNION SELECT
    'Account owner must be GATHER for Bank:Gather and Bank:Cash postings' AS message,
    JSONB_BUILD_OBJECT(
        'journal_id', j.id,
        'description', j.description,
        'posting_id', p.id,        
        'owner', p.owner
    ) AS trace
FROM ledger_staging.batch b
JOIN ledger_staging.journal j ON j.batch_id = b.id
JOIN ledger_staging.posting p ON p.journal_id = j.id
WHERE b.id = _batch_id AND
    p.account IN (1110, 1111) AND p.owner != 'GATHER'

-- Rule #7:
UNION SELECT m.message, m.trace
    FROM (
        SELECT 'Batch does not exist' AS message,
        JSONB_BUILD_OBJECT('batch_id', _batch_id) AS trace
    ) AS m
    LEFT JOIN ledger_staging.batch b ON b.id = _batch_id
    WHERE b.id IS NULL -- only return records where batch does not exist

-- Rule #8:
UNION SELECT
    'Batch has no postings' AS message,
    JSONB_BUILD_OBJECT('batch_id', b.id) AS trace
FROM ledger_staging.batch b
LEFT JOIN ledger_staging.journal j ON j.batch_id = b.id
LEFT JOIN ledger_staging.posting p ON p.journal_id = j.id
WHERE b.id = _batch_id
GROUP BY b.id
HAVING COUNT(p.id) = 0

;
END; $$
LANGUAGE 'plpgsql';

/* Attempt to commit a staged batch of journal entries
   First, it will validate that the staged batch has no errors
   If the staged batch has errors, then a record set of errors will be returned
   If there are no errors in the staged batch, then it will commit ledger_staging tables into ledger tables
   A successful commit will return an empty recordset (no rows)
*/
CREATE FUNCTION ledger.commit_batch (_batch_id INTEGER)
    RETURNS TABLE (message TEXT, trace JSONB)
AS $$
DECLARE
    error_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO error_count FROM ledger.validate_batch(_batch_id);
    IF error_count > 0 THEN
        -- Return the listing of errors
        RETURN QUERY SELECT * FROM ledger.validate_batch(_batch_id);
        RETURN; -- Return query doesn't exit function, it adds to the result set
    ELSE
        -- Copy the staging batch into a committed batch
        INSERT INTO ledger.batch (created_by, purpose, stage_id)
        SELECT sb.created_by, sb.purpose, _batch_id
        FROM ledger_staging.batch sb
        WHERE sb.id = _batch_id;

        -- Copy the staging journals into the committed journals
        INSERT INTO ledger.journal (batch_id, type, description, period, funeral_home_case_id, invoice_id, pgp_id, stage_id, revision_id, batch_invoice_number, batch_invoice_number_condensed)
        SELECT b.id, sj.type, sj.description, sj.period, sj.funeral_home_case_id, sj.invoice_id, sj.pgp_id, sj.id, sj.revision_id, sj.batch_invoice_number, sj.batch_invoice_number_condensed
        FROM ledger_staging.journal sj
        JOIN ledger.batch b ON b.stage_id = _batch_id
        WHERE sj.batch_id = _batch_id;

        -- Copy the staging postings into the committed postings
        INSERT INTO ledger.posting (journal_id, owner, account, customer_id, vendor_id, asset_type, debit, credit, memo, is_tax, is_fee, contract_item_id, external_id, is_reversal)
        SELECT j.id, sp.owner, sp.account, sp.customer_id, sp.vendor_id, sp.asset_type, sp.debit, sp.credit, sp.memo, sp.is_tax, sp.is_fee, sp.contract_item_id, sp.external_id, sp.is_reversal
        FROM ledger_staging.posting sp
        JOIN ledger.batch b ON b.stage_id = _batch_id
        JOIN ledger.journal j ON j.batch_id = b.id
        WHERE sp.journal_id = j.stage_id;

        -- Delete the staging batch (cascade deletes journals and postings)
        DELETE FROM ledger_staging.batch WHERE id = _batch_id;

        -- Return an empty recordset to indicate success
        RETURN QUERY SELECT '' AS message, '{}'::JSONB AS trace WHERE FALSE;
        RETURN; -- Return query doesn't exit function, it adds to the result set
    END IF;
END; $$
LANGUAGE 'plpgsql' SECURITY DEFINER;

CREATE FUNCTION ledger.reverse_journals(
    _reversed_by INTEGER,
    _reversed_reason TEXT,
    _journal_ids INTEGER[]
)
RETURNS TABLE (id INTEGER)
AS $reverse_journals$
DECLARE
    _reversal_journal_id INTEGER;
    _reversal_batch_id INTEGER;
    _first_journal_id INTEGER;
    _type TEXT;
    _description TEXT;
    _period CHAR(7);
    _funeral_home_case_id INTEGER;
    _invoice_id INTEGER;
    _pgp_id INTEGER;
    _stage_id INTEGER;
    _outside_contract_revision INTEGER;
    _hex_case_id TEXT;
    _batch_invoice_number TEXT;
    _batch_invoice_number_condensed TEXT;
    _first_batch_invoice_number TEXT;
BEGIN
   IF array_length(_journal_ids, 1) IS NULL OR array_length(_journal_ids, 1) = 0 THEN
        RAISE LOG 'No journal IDs provided';
        RETURN;
   END IF;

    -- Get the first journal id from the array
    SELECT UNNEST(_journal_ids) INTO _first_journal_id LIMIT 1;

    -- Get details from the first journal
    SELECT j.type, j.description, j.period, j.funeral_home_case_id, j.invoice_id, j.pgp_id,
           j.stage_id, j.batch_invoice_number
      INTO _type, _description, _period, _funeral_home_case_id, _invoice_id,
           _pgp_id, _stage_id, _first_batch_invoice_number
      FROM ledger.journal j
    WHERE j.id = _first_journal_id;

    -- Only generate new batch invoice number if original is not null and contains 'Outside'
    IF _first_batch_invoice_number IS NOT NULL
       AND POSITION('Outside' IN _first_batch_invoice_number) > 0 THEN

        -- Determine the next outside_contract_revision
        SELECT COUNT(DISTINCT j.id) + 1
          INTO _outside_contract_revision
          FROM ledger.journal j
        WHERE j.type = 'INVOICE'
          AND j.revision_id IS NULL
          AND j.funeral_home_case_id = _funeral_home_case_id;

        -- Generate "Outside" batch invoice numbers
        _hex_case_id := lpad(to_hex(_funeral_home_case_id), 7, '0');

        _batch_invoice_number := 'Inv_' || _hex_case_id || '.' ||
                                 lpad(_outside_contract_revision::text, 2, '0') || '_Outside';

        _batch_invoice_number_condensed := 'o' || _hex_case_id || '.' ||
                                           lpad(_outside_contract_revision::text, 2, '0');
    ELSE
        _batch_invoice_number := NULL;
        _batch_invoice_number_condensed := NULL;
    END IF;

    -- Create a new batch with a purpose referencing the first journal
    INSERT INTO ledger.batch (created_by, purpose)
    VALUES (_reversed_by, 'Reversal on Journal ' || _first_journal_id)
    RETURNING ledger.batch.id INTO _reversal_batch_id;

    -- Create a single reversal journal, copying details from the first journal
    INSERT INTO ledger.journal (
        batch_id, type, description, period, funeral_home_case_id, invoice_id, pgp_id, entered_time,
        stage_id, 
        batch_invoice_number, batch_invoice_number_condensed
    )
    VALUES (
        _reversal_batch_id, _type, _description, _period, _funeral_home_case_id, _invoice_id, _pgp_id, NOW(),
        _stage_id,
        _batch_invoice_number, _batch_invoice_number_condensed
    )
    RETURNING ledger.journal.id INTO _reversal_journal_id;

    -- Insert reversal postings for all journals into the new journal, with is_reversal = true
    INSERT INTO ledger.posting (
        journal_id, owner, account, customer_id, vendor_id, asset_type,
        debit, credit, memo, is_tax, is_fee, contract_item_id, external_id, is_reversal
    )
    SELECT
        _reversal_journal_id, p.owner, p.account, p.customer_id, p.vendor_id, p.asset_type,
        p.credit, p.debit, 'REVERSED: ' || p.memo, p.is_tax, p.is_fee, p.contract_item_id, p.external_id, TRUE
    FROM ledger.posting p
    WHERE p.journal_id = ANY(_journal_ids);

    -- Mark all original journals as reversed
    UPDATE ledger.journal j
    SET reversed_time = NOW(), reversed_by = _reversed_by, reversed_reason = _reversed_reason
    WHERE j.id = ANY(_journal_ids);

    -- Return the original journal ids that were reversed
    RETURN QUERY
    SELECT j.id FROM ledger.journal j WHERE j.id = ANY(_journal_ids);
END;
$reverse_journals$
LANGUAGE plpgsql SECURITY DEFINER;

-- END APP-493

CREATE FUNCTION ledger.mark_journals_as_reversed(_reversed_by INTEGER, _reversed_reason TEXT, _journal_ids INTEGER[])
RETURNS TABLE (
    account INTEGER,
    debit BIGINT,
    credit BIGINT,
    memo TEXT,
    is_tax BOOLEAN,
    is_fee BOOLEAN,
    is_reversal BOOLEAN
)
AS $$
BEGIN
    RETURN QUERY SELECT
        p.account,
        p.debit,
        p.credit,
        p.memo,
        p.is_tax,
        p.is_fee,
        p.is_reversal
    FROM ledger.posting p
	JOIN ledger.journal j
		ON j.id = p.journal_id
    WHERE p.journal_id IN (SELECT UNNEST(_journal_ids))
	AND j.reversed_time IS NULL
	AND p.is_reversal = FALSE;

	WITH journals AS (
    SELECT j.id
    FROM ledger.journal j
    WHERE j.id IN (SELECT UNNEST(_journal_ids))
        AND j.reversed_time IS NULL
	)
	UPDATE ledger.journal j SET
        reversed_by = _reversed_by,
        reversed_reason = _reversed_reason,
        reversed_time = NOW()
    WHERE j.id IN (SELECT id FROM journals);
END; $$
LANGUAGE 'plpgsql' SECURITY DEFINER;

CREATE FUNCTION ledger.create_extract (
  _funeral_home_id INTEGER,
  _type TEXT,
  _account INTEGER,
  _created_by INTEGER,
  _create_credit_memos BOOLEAN DEFAULT FALSE,
  OUT _id INTEGER,
  OUT _cm_id INTEGER
)
AS $$
BEGIN
    -- Create a temporary table to store the statements per customer/case 
    CREATE TEMPORARY TABLE statements ON COMMIT DROP AS
	    SELECT       
	      fh_case.gather_case_id,
	      SUM(COALESCE(p.debit, 0) - COALESCE(p.credit, 0))::BIGINT AS statement_total
	    FROM ledger.posting p
	    JOIN ledger.journal j
	      ON j.id = p.journal_id
	    JOIN invoice ON invoice.id = j.invoice_id
	    JOIN funeral_home_case AS fh_case ON fh_case.id = invoice.funeral_home_case_id
	    JOIN gather_case gc ON gc.id = fh_case.gather_case_id
	    JOIN entity AS customer
	      ON customer.id = p.customer_id
	    WHERE fh_case.funeral_home_id = _funeral_home_id
	      AND invoice.is_fee = FALSE
	      AND gc.is_test = FALSE
	      AND gc.deleted_time IS NULL
	      AND fh_case.deleted_time IS NULL
	      AND fh_case.case_type != 'pre-need'
	      AND j.type = 'INVOICE'
	      AND p.extract_id IS NULL
	      AND p.account = 1200
	      AND p.owner = 'FH'
	      AND p.is_fee = FALSE
	      AND customer.type = 'customer'
	   GROUP BY fh_case.gather_case_id
	   ORDER BY fh_case.gather_case_id;

    -- If create_credit_memos is true, we are closing out invoices, and there are negative invoice totals, create credit memos
    IF _create_credit_memos AND EXISTS (SELECT 1 FROM statements WHERE statement_total < 0) AND _type = 'INVOICE' THEN

      INSERT INTO ledger.extract (owner, funeral_home_id, type, account, created_by) VALUES
      ('FH', _funeral_home_id, _type, _account, _created_by) RETURNING id INTO _cm_id;

      WITH postings AS (
    -- Find all of the non-extracted postings that are tied to this FH
        SELECT DISTINCT p.id
        FROM ledger.posting p
        JOIN ledger.journal j ON j.id = p.journal_id
        JOIN funeral_home_case AS fh_case
        ON fh_case.id = j.funeral_home_case_id
        JOIN entity ON entity.id = p.customer_id
        -- If an invoice doesn't exist for this case, then postings shouldn't be closed (payments)
        JOIN invoice ON invoice.funeral_home_case_id = j.funeral_home_case_id AND invoice.is_fee = FALSE
        -- Only include postings that have a negative statement total from the statements temp table
        JOIN statements ON statements.gather_case_id = fh_case.gather_case_id AND statement_total < 0
        WHERE
        p.extract_id IS NULL
        AND fh_case.case_type != 'pre-need'
        AND fh_case.funeral_home_id = _funeral_home_id
        AND j.type = _type
        AND p.account = _account
        AND p.owner = 'FH'
        AND entity.type = 'customer'
    ) UPDATE ledger.posting p
    SET extract_id = _cm_id
    FROM postings
    WHERE p.id = postings.id;
    
    END IF;

  -- Make sure we have positive statements to create an extract if we are creating credit memos
  -- OR just create a statement if we are not creating credit memos or if its NOT and invoice batch
	IF (_create_credit_memos AND EXISTS (SELECT 1 FROM statements WHERE statement_total >= 0))
		OR NOT _create_credit_memos OR _type != 'INVOICE' THEN

	  INSERT INTO ledger.extract (owner, funeral_home_id, type, account, created_by) VALUES
	      ('FH', _funeral_home_id, _type, _account, _created_by) RETURNING id INTO _id;
	
	  WITH postings AS (
	    -- Find all of the non-extracted postings that are tied to this FH
	    SELECT DISTINCT p.id
	    FROM ledger.posting p
	    JOIN ledger.journal j ON j.id = p.journal_id
	    JOIN funeral_home_case AS fh_case
	      ON fh_case.id = j.funeral_home_case_id
	    JOIN entity ON entity.id = p.customer_id
	    -- If an invoice doesn't exist for this case, then postings shouldn't be closed (payments)
	    JOIN invoice ON invoice.funeral_home_case_id = j.funeral_home_case_id AND invoice.is_fee = FALSE
	    WHERE
	      p.extract_id IS NULL
	      AND fh_case.case_type != 'pre-need'
	      AND fh_case.funeral_home_id = _funeral_home_id
	      AND j.type = _type
	      AND p.account = _account
	      AND p.owner = 'FH'
	      AND entity.type = 'customer'
	  ) UPDATE ledger.posting p
	  SET extract_id = _id
	  FROM postings
	  WHERE p.id = postings.id;

    END IF;

END; $$
LANGUAGE 'plpgsql' SECURITY DEFINER;

CREATE TABLE service_template (
  id               SERIAL PRIMARY KEY,
  name             TEXT UNIQUE NOT NULL,
  key              extensions.CITEXT UNIQUE NOT NULL,
  description      TEXT,
  created_by       INTEGER NOT NULL REFERENCES user_profile(id),
  created_time     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deactivated_by   INTEGER REFERENCES user_profile(id),
  deactivated_time TIMESTAMP WITH TIME ZONE,
  updated_by       INTEGER NOT NULL REFERENCES user_profile(id),
  updated_time     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  all_funeral_homes BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE service_template_funeral_home (
  service_template_id INTEGER REFERENCES service_template(id),
  funeral_home_id     INTEGER REFERENCES funeral_home(id),
  created_by          INTEGER NOT NULL REFERENCES user_profile(id),
  created_time        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deactivated_by      INTEGER REFERENCES user_profile(id),
  deactivated_time    TIMESTAMP WITH TIME ZONE,
  CONSTRAINT service_template_funeral_home_pkey PRIMARY KEY(service_template_id, funeral_home_id)
);

CREATE TABLE default_service_detail (
  id                        SERIAL PRIMARY KEY,
  title                     TEXT NOT NULL,
  key                       extensions.CITEXT UNIQUE NOT NULL,
  explainer_text            TEXT NOT NULL,
  can_edit_title_by_user    BOOLEAN NOT NULL DEFAULT FALSE,
  can_sort_fields_by_user   BOOLEAN NOT NULL DEFAULT FALSE,
  can_be_deleted_by_user    BOOLEAN NOT NULL DEFAULT FALSE,
  can_user_add_music        BOOLEAN NOT NULL DEFAULT FALSE,
  add_music_label           TEXT NOT NULL DEFAULT 'Type music information here...',
  can_user_add_person       BOOLEAN NOT NULL DEFAULT FALSE,
  add_person_label          TEXT NOT NULL DEFAULT 'Start typing to see a list of people...',
  can_user_add_text         BOOLEAN NOT NULL DEFAULT FALSE,
  add_text_label            TEXT NOT NULL DEFAULT 'Type additional info here...',
  can_be_deleted            BOOLEAN NOT NULL DEFAULT TRUE,
  data                      JSONB,
  created_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  updated_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE service_detail (
  id                        SERIAL PRIMARY KEY,
  title                     TEXT NOT NULL,
  key                       extensions.CITEXT NOT NULL,
  explainer_text            TEXT NOT NULL,
  can_edit_title_by_user    BOOLEAN NOT NULL DEFAULT FALSE,
  can_sort_fields_by_user   BOOLEAN NOT NULL DEFAULT FALSE,
  can_be_deleted_by_user    BOOLEAN NOT NULL DEFAULT FALSE,
  can_user_add_music        BOOLEAN NOT NULL DEFAULT FALSE,
  add_music_label           TEXT NOT NULL,
  can_user_add_person       BOOLEAN NOT NULL DEFAULT FALSE,
  add_person_label          TEXT ,
  can_user_add_text         BOOLEAN NOT NULL DEFAULT FALSE,
  add_text_label            TEXT,
  can_be_deleted            BOOLEAN NOT NULL DEFAULT TRUE,
  detail_order              INTEGER NOT NULL,
  gather_case_id            INTEGER REFERENCES gather_case(id),
  data                      JSONB,
  default_service_detail_id INTEGER REFERENCES default_service_detail(id),
  version                   INTEGER NOT NULL DEFAULT 1,
  created_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deactivated_by            INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  deactivated_time          TIMESTAMP WITH TIME ZONE,
  updated_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  updated_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Update gather_case.service_template_id to be FK reference
ALTER TABLE gather_case ADD FOREIGN KEY (service_template_id) REFERENCES service_template(id);
CREATE INDEX service_detail_gather_case_idx ON service_detail(gather_case_id);

CREATE TABLE service_template_detail (
  id                        SERIAL PRIMARY KEY,
  service_template_id       INTEGER REFERENCES service_template(id),
  default_service_detail_id INTEGER REFERENCES default_service_detail(id),
  detail_order              INTEGER NOT NULL,
  created_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deactivated_by            INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  deactivated_time          TIMESTAMP WITH TIME ZONE,
  updated_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  updated_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- START APP-520
CREATE SCHEMA product;

CREATE TABLE product.manufacturer (
  id                        SERIAL PRIMARY KEY,
  name                      TEXT NOT NULL UNIQUE,
  external_link             TEXT
);

CREATE TYPE product.category AS ENUM ('care_of_loved_one', 'transportation', 'equipment_facilities_staff', 'casket', 'urn', 'vault', 'cemetery', 'memorial', 'flowers', 'cash_advance');
CREATE TYPE product.category_group AS ENUM('professional_services', 'merchandise', 'cash_advance', 'other');

ALTER TABLE public.invoice ADD COLUMN product_category product.category;

CREATE FUNCTION product.cast_category_to_group(_category product.category)
RETURNS product.category_group AS 
$$ 
DECLARE 
    cg product.category_group;
BEGIN
  CASE
    WHEN _category = 'care_of_loved_one' THEN cg = 'professional_services';
    WHEN _category = 'transportation' THEN cg = 'professional_services';
    WHEN _category = 'equipment_facilities_staff' THEN cg = 'professional_services';
    WHEN _category = 'casket' THEN cg = 'merchandise';
    WHEN _category = 'urn' THEN cg = 'merchandise';
    WHEN _category = 'vault' THEN cg = 'merchandise';
    WHEN _category = 'cemetery' THEN cg = 'merchandise';
    WHEN _category = 'memorial' THEN cg = 'merchandise';
    WHEN _category = 'flowers' THEN cg = 'merchandise';
    WHEN _category = 'cash_advance' THEN cg = 'cash_advance';
    WHEN _category IS NULL THEN cg = 'other';
    ELSE cg = 'other';
  END CASE ;
  return cg AS category_group;
END
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE CAST (product.category as product.category_group) WITH FUNCTION product.cast_category_to_group(product.category);

CREATE TABLE product.tax_rate (
  id                        SERIAL PRIMARY KEY,
  name                      TEXT NOT NULL,
  description               TEXT,
  state                     TEXT NOT NULL,
  county                    TEXT NOT NULL,
  asset_type                ledger.asset_type NOT NULL DEFAULT 'USD'
);

ALTER TABLE public.invoice ADD COLUMN tax_rate_id INTEGER REFERENCES product.tax_rate(id) ON DELETE SET NULL;

CREATE TABLE product.tax_rate_bracket (
  id                        SERIAL PRIMARY KEY,
  tax_rate_id               INTEGER NOT NULL REFERENCES product.tax_rate(id) ON DELETE CASCADE,
  minimum                   INTEGER NOT NULL,
  maximum                   INTEGER,
  rate                      DECIMAL(7, 4) NOT NULL
);

CREATE TABLE product.tag (
  category                  product.category NOT NULL,
  name                      TEXT NOT NULL,
  value                     TEXT NOT NULL,
  PRIMARY KEY (category, name, value)
);

CREATE TYPE product.pricing_model AS ENUM ('fixed', 'base_plus_variable', 'variable', 'allowance', 'manual');

CREATE TABLE product.product (
  id                        SERIAL PRIMARY KEY,
  name                      TEXT NOT NULL,
  description               TEXT,
  sku                       TEXT,
  manufacturer_id           INTEGER REFERENCES product.manufacturer(id) ON DELETE SET NULL,
  category                  product.category NOT NULL,
  model_number              TEXT,
  external_link             TEXT,
  funeral_home_id           INTEGER REFERENCES funeral_home(id) ON DELETE CASCADE,
  is_package_exclusive      BOOLEAN NOT NULL DEFAULT FALSE,
  is_hidden                 BOOLEAN NOT NULL DEFAULT FALSE,
  category_rank             INTEGER NOT NULL,
  featured_rank             INTEGER,
  photos                    TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],  -- list of photo.public_id instead of JOIN table to make clones easier
  tags                      JSONB NOT NULL DEFAULT '{}'::jsonb, -- contains product.tag key:value pairs instead of using a FK to make clones easier
  pricing_model             product.pricing_model NOT NULL,
  cost                      INTEGER,
  base_price                INTEGER,
  base_quantity             INTEGER,
  var_price                 INTEGER,
  var_increment             INTEGER,
  var_increment_units       TEXT,
  var_max_quantity          INTEGER,
  var_default_quantity      INTEGER,
  tax_rate_id               INTEGER REFERENCES product.tax_rate(id) ON DELETE SET NULL,
  asset_type                ledger.asset_type NOT NULL DEFAULT 'USD',
  cloned_from               INTEGER REFERENCES product.product(id) ON DELETE SET NULL,
  cloned_time               TIMESTAMP WITH TIME ZONE,
  created_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  updated_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  deleted_time              TIMESTAMP WITH TIME ZONE,
  is_always_displayed       BOOLEAN NOT NULL DEFAULT FALSE,
  use_na_when_always_displayed BOOLEAN NOT NULL DEFAULT FALSE,
  display_model_number      BOOLEAN NOT NULL DEFAULT FALSE,
  display_manufacturer      BOOLEAN NOT NULL DEFAULT FALSE,
  display_tags              BOOLEAN NOT NULL DEFAULT FALSE,
  persistent_contract_text  TEXT,
  bold_contract_text        BOOLEAN NOT NULL DEFAULT FALSE,
  underline_contract_text   BOOLEAN NOT NULL DEFAULT FALSE,
  indent_contract_text      BOOLEAN NOT NULL DEFAULT FALSE,
  show_on_website           BOOLEAN NOT NULL DEFAULT FALSE,
  show_price_on_website     BOOLEAN NOT NULL DEFAULT FALSE,
  fh_cloned_from            INTEGER REFERENCES product.product(id) ON DELETE SET NULL,
  fh_cloned_time            TIMESTAMP WITH TIME ZONE
);

CREATE INDEX product_funeral_home_idx ON product.product(funeral_home_id);
CREATE INDEX product_cloned_from_idx ON product.product(cloned_from);
CREATE INDEX product_fh_cloned_from_idx ON product.product(fh_cloned_from);

ALTER TABLE public.invoice ADD COLUMN product_id INTEGER REFERENCES product.product(id) ON DELETE SET NULL;
CREATE INDEX invoice_product_id_idx ON invoice(product_id);

CREATE TABLE product.package (
  id                        SERIAL PRIMARY KEY,
  name                      TEXT NOT NULL,
  description               TEXT,
  funeral_type              funeral_type[] NOT NULL,
  category                  product.category,
  funeral_home_id           INTEGER NOT NULL REFERENCES funeral_home(id) ON DELETE CASCADE,
  price                     INTEGER,
  asset_type                ledger.asset_type NOT NULL DEFAULT 'USD',
  photos                    TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],  -- list of photo.public_id
  is_discount_displayed     BOOLEAN NOT NULL DEFAULT FALSE,
  replaces_package          INTEGER UNIQUE REFERENCES product.package(id) ON DELETE SET NULL,
  original_package          INTEGER REFERENCES product.package(id) ON DELETE SET NULL,
  created_by                INTEGER NOT NULL REFERENCES user_profile(id),
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by                INTEGER NOT NULL REFERENCES user_profile(id),
  updated_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by                INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  deleted_time              TIMESTAMP WITH TIME ZONE,
  fh_cloned_from            INTEGER REFERENCES product.package(id) ON DELETE SET NULL,
  fh_cloned_time            TIMESTAMP WITH TIME ZONE,
  rank                      INTEGER NOT NULL,
  show_on_website           BOOLEAN NOT NULL DEFAULT FALSE,
  show_price_on_website     BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT valid_package_revision CHECK (
    original_package IS NULL OR (original_package IS NOT NULL AND replaces_package IS NOT NULL)
  )
);

CREATE INDEX package_funeral_home_idx ON product.package(funeral_home_id);

CREATE TABLE product.package_item (
  id                        SERIAL PRIMARY KEY,
  package_id                INTEGER NOT NULL REFERENCES product.package(id) ON DELETE CASCADE,
  name                      TEXT NOT NULL,
  max_selections            INTEGER NOT NULL,
  category                  product.category,
  fh_cloned_from            INTEGER REFERENCES product.package_item(id) ON DELETE SET NULL,
  fh_cloned_time            TIMESTAMP WITH TIME ZONE
);

CREATE INDEX package_item_package_idx ON product.package_item(package_id);

CREATE TABLE product.package_item_option (
  id                        SERIAL PRIMARY KEY,
  package_item_id           INTEGER NOT NULL REFERENCES product.package_item(id) ON DELETE CASCADE,
  product_id                INTEGER REFERENCES product.product(id) ON DELETE CASCADE,
  sub_package_id            INTEGER REFERENCES product.package(id) ON DELETE CASCADE,
  fh_cloned_from            INTEGER REFERENCES product.package_item_option(id) ON DELETE SET NULL,
  fh_cloned_time            TIMESTAMP WITH TIME ZONE,
  CONSTRAINT has_product_or_sub_package CHECK (product_id IS NOT NULL OR sub_package_id IS NOT NULL)
);

CREATE INDEX package_item_option_package_item_idx ON product.package_item_option(package_item_id);
CREATE INDEX package_item_option_product_id_idx ON product.package_item_option(product_id);

CREATE TYPE product.taxation_method AS ENUM ('per_item_basis', 'contract_basis', 'exempt');

CREATE TYPE print_page_size_type AS ENUM ( 'Letter' , 'Legal' , 'Tabloid' , 'Ledger' , 'A0' , 'A1' , 'A2' , 'A3' , 'A4' , 'A5' , 'A6');
CREATE TYPE product.package_view_type AS ENUM ('list', 'grouped', 'package_only');

CREATE TABLE product.contract_options (
  funeral_home_id           INTEGER NOT NULL REFERENCES funeral_home(id) ON DELETE CASCADE PRIMARY KEY,
  legal_top                 TEXT,
  legal_bottom              TEXT,
  legal_pro_services        TEXT,
  legal_merchandise         TEXT,
  legal_cash_advances       TEXT,
  legal_contract_disclaimer TEXT,
  legal_invoice             TEXT,
  legal_use_markdown        BOOLEAN NOT NULL DEFAULT FALSE,
  default_taxation_method   product.taxation_method NOT NULL DEFAULT 'per_item_basis',
  default_contract_tax_rate INTEGER REFERENCES product.tax_rate(id) ON DELETE SET NULL,
  default_item_tax_rate     INTEGER REFERENCES product.tax_rate(id) ON DELETE SET NULL,
  include_fh_license        BOOLEAN NOT NULL DEFAULT FALSE,
  include_fh_extra_field    BOOLEAN NOT NULL DEFAULT FALSE,
  fh_extra_field_name       TEXT,
  is_fh_extra_field_req     BOOLEAN NOT NULL DEFAULT FALSE,
  include_fam_address       BOOLEAN NOT NULL DEFAULT FALSE,
  include_fam_phone         BOOLEAN NOT NULL DEFAULT FALSE,
  include_fam_email         BOOLEAN NOT NULL DEFAULT FALSE,
  include_fam_extra_field   BOOLEAN NOT NULL DEFAULT FALSE,
  fam_extra_field_name      TEXT,
  is_fam_extra_field_req    BOOLEAN NOT NULL DEFAULT FALSE,
  hide_package_item_prices  BOOLEAN NOT NULL DEFAULT FALSE,
  fh_cloned_from            INTEGER REFERENCES funeral_home(id) ON DELETE SET NULL,
  fh_cloned_time            TIMESTAMP WITH TIME ZONE,
  print_page_size           print_page_size_type NOT NULL DEFAULT 'Letter',
  use_five_category_groups  BOOLEAN NOT NULL DEFAULT FALSE,
  use_two_category_groups   BOOLEAN NOT NULL DEFAULT FALSE,
  package_view              product.package_view_type NOT NULL DEFAULT 'list',
  equal_contract_spacing    BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE product.contract (
  id                        SERIAL PRIMARY KEY,
  funeral_home_case_id      INTEGER NOT NULL REFERENCES funeral_home_case(id),
  created_by                INTEGER NOT NULL REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  taxation_method           product.taxation_method NOT NULL,
  tax_rate_id               INTEGER REFERENCES product.tax_rate(id) ON DELETE SET NULL,
  sub_total                 BIGINT,
  tax_total                 BIGINT,
  asset_type                ledger.asset_type NOT NULL DEFAULT 'USD',
  hide_revisions            BOOLEAN NOT NULL DEFAULT FALSE,
  statement_date            TIMESTAMP WITH TIME ZONE,
  -- this is denormalized, and should be NOT NULL but it is an order of operations problem, so it is not possible to set the schema that way
  -- latest_revision_id        INTEGER REFERENCES product.contract_revision(id) -- added later in schema
  first_frozen_date         TIMESTAMP WITH TIME ZONE,
  last_frozen_date          TIMESTAMP WITH TIME ZONE
);

CREATE INDEX contract_funeral_home_case_id_idx ON product.contract(funeral_home_case_id);
CREATE INDEX contract_created_time_idx ON product.contract(created_time);
CREATE INDEX contract_first_frozen_date_idx ON product.contract(first_frozen_date);
CREATE INDEX contract_last_frozen_date_idx ON product.contract(last_frozen_date);

CREATE TABLE product.contract_revision (
  id                        SERIAL PRIMARY KEY,
  photos                    TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],  -- list of photo.public_id
  contract_id               INTEGER NOT NULL REFERENCES product.contract(id) ON DELETE CASCADE,
  invoice_id                INTEGER REFERENCES invoice(id) ON DELETE SET NULL,
  taxation_method           product.taxation_method NOT NULL,
  created_by                INTEGER NOT NULL REFERENCES user_profile(id) ON DELETE SET NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  frozen_by                 INTEGER REFERENCES user_profile(id) ON DELETE SET NULL,
  frozen_time               TIMESTAMP WITH TIME ZONE,
  revision_number           INTEGER NOT NULL, -- this is denormalized, and should be unique to the contract_id
  UNIQUE (contract_id, revision_number)
);
CREATE UNIQUE INDEX unique_unfrozen_revision_per_contract
ON product.contract_revision (contract_id)
WHERE frozen_time IS NULL;
CREATE INDEX contract_revision_invoice_id_idx ON product.contract_revision(invoice_id);
CREATE INDEX contract_revision_contract_id_idx ON product.contract_revision(contract_id);
CREATE INDEX contract_revision_frozen_time_idx ON product.contract_revision(frozen_time);

ALTER TABLE product.contract ADD COLUMN latest_revision_id INTEGER REFERENCES product.contract_revision(id);
ALTER TABLE ledger.journal ADD COLUMN revision_id INTEGER REFERENCES product.contract_revision(id) ON DELETE SET NULL;
ALTER TABLE ledger_staging.journal ADD COLUMN revision_id INTEGER REFERENCES product.contract_revision(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION product.trigger_set_contract_revision_number()
RETURNS TRIGGER AS $$
DECLARE
    next_revision_number INTEGER;
BEGIN
    -- get the next revision number and set it on the new row being created
    SELECT COALESCE(MAX(revision_number), 0) + 1 INTO next_revision_number
    FROM product.contract_revision
    WHERE contract_id = NEW.contract_id;
    NEW.revision_number := next_revision_number;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_contract_revision_number_trig
BEFORE INSERT ON product.contract_revision
FOR EACH ROW
EXECUTE FUNCTION product.trigger_set_contract_revision_number();

CREATE TYPE product.contract_item_type AS ENUM ('normal', 'package_discount', 'package_placeholder', 'allowance_credit', 'contract_discount');

CREATE TABLE product.contract_item (
  id                        TEXT PRIMARY KEY,
  contract_id               INTEGER NOT NULL REFERENCES product.contract(id) ON DELETE CASCADE,
  product_id                INTEGER REFERENCES product.product(id) ON DELETE SET NULL,
  package_id                INTEGER REFERENCES product.package(id) ON DELETE SET NULL,
  sub_package_id            INTEGER REFERENCES product.package(id) ON DELETE SET NULL,
  package_item_id           INTEGER REFERENCES product.package_item(id) ON DELETE SET NULL,
  allowance_item            TEXT REFERENCES product.contract_item(id) ON DELETE SET NULL,
  insert_revision           INTEGER NOT NULL REFERENCES product.contract_revision(id) ON DELETE CASCADE,
  delete_revision           INTEGER REFERENCES product.contract_revision(id) ON DELETE CASCADE,
  replaces_item             TEXT UNIQUE REFERENCES product.contract_item(id) ON DELETE SET NULL,
  original_item             TEXT REFERENCES product.contract_item(id) ON DELETE SET NULL,
  type                      product.contract_item_type NOT NULL,
  category                  product.category,
  name                      TEXT NOT NULL,
  description               TEXT,
  sku                       TEXT,
  note                      TEXT,
  quantity                  INTEGER NOT NULL,
  quantity_in_package       INTEGER,
  list_price                INTEGER NOT NULL,
  price_adjustment          INTEGER NOT NULL DEFAULT 0,
  tax_total                 DECIMAL(8, 2) NOT NULL DEFAULT 0.0,
  tax_rate_id               INTEGER REFERENCES product.tax_rate(id) ON DELETE SET NULL,
  tax_rate_brackets         TEXT,
  asset_type                ledger.asset_type NOT NULL DEFAULT 'USD',
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  display_name              TEXT,
  CONSTRAINT valid_sub_package_id CHECK (
    sub_package_id IS NULL OR package_id IS NOT NULL
  ),
  CONSTRAINT valid_package_item_id CHECK (
    package_item_id IS NULL OR package_id IS NOT NULL
  ),
  CONSTRAINT valid_contract_item_type CHECK (
    package_id IS NULL OR product_id IS NOT NULL OR type = 'package_placeholder' OR type = 'package_discount' OR type = 'allowance_credit'
  ),
  CONSTRAINT valid_package_placeholder CHECK (
    type != 'package_placeholder' OR (package_id IS NOT NULL AND product_id IS NULL AND package_item_id IS NOT NULL)
  ),
  CONSTRAINT valid_package_discount CHECK (
    type != 'package_discount' OR (package_id IS NOT NULL AND product_id IS NULL)
  ),
  CONSTRAINT valid_allowance_credit CHECK (
    type != 'allowance_credit' OR (package_id IS NOT NULL AND product_id IS NULL AND allowance_item IS NOT NULL)
  ),
  CONSTRAINT valid_item_revision CHECK (
    original_item IS NULL OR (original_item IS NOT NULL AND replaces_item IS NOT NULL)
  )
);

CREATE INDEX contract_item_sub_package_idx ON product.contract_item(sub_package_id);
CREATE INDEX contract_item_package_idx ON product.contract_item(package_id);
CREATE INDEX contract_item_product_idx ON product.contract_item(product_id);
CREATE INDEX contract_item_contract_idx ON product.contract_item(contract_id);
CREATE INDEX contract_item_delete_revision_idx ON product.contract_item(delete_revision);
CREATE INDEX contract_item_insert_revision_idx ON product.contract_item(insert_revision);
-- these indexes are important when deleting an item
CREATE INDEX contract_item_original_item_idx ON product.contract_item(original_item);
CREATE INDEX contract_item_allowance_item_idx ON product.contract_item(allowance_item);

CREATE INDEX contract_item_created_time_idx ON product.contract_item(created_time);
CREATE INDEX contract_item_updated_time_idx ON product.contract_item(updated_time);

ALTER TABLE ledger_staging.posting
  ADD CONSTRAINT fk_ledger_posting_contract_item_id
  FOREIGN KEY (contract_item_id)
  REFERENCES product.contract_item(id)
  ON DELETE CASCADE;

ALTER TABLE ledger.posting
  ADD CONSTRAINT fk_ledger_posting_contract_item_id
  FOREIGN KEY (contract_item_id)
  REFERENCES product.contract_item(id)
  ON DELETE CASCADE;

-- this index is important when deleting a contract_item
CREATE INDEX ledger_posting_contract_item_id_idx ON ledger.posting(contract_item_id);

-- Any changes to this function need to also be reflected in dbscripts/ledger/[getProposedInvoicesForCase.sql, getProposedPaymentsForCase.sql, and getTransactionsForCase.sql]
CREATE FUNCTION set_case_totals (_funeral_home_case_id INTEGER)
    RETURNS TABLE (
        funeral_home_case_id INTEGER,
        uuid                UUID,
        expense_total       BIGINT,
        collected_total     BIGINT,
        proposed_total      BIGINT,
        tax_total           BIGINT,
        statement_adjustments_total BIGINT,
        merch_pretax_sales_total   BIGINT,
        proserve_pretax_sales_total BIGINT,
        cashadv_pretax_sales_total BIGINT,
        care_of_loved_one_pretax_sales_total BIGINT,
        transportation_pretax_sales_total BIGINT,
        use_of_facilities_pretax_sales_total BIGINT,
        casket_pretax_sales_total BIGINT,
        urn_pretax_sales_total BIGINT,
        vault_pretax_sales_total BIGINT,
        cemetery_pretax_sales_total BIGINT,
        memorial_pretax_sales_total BIGINT,
        flowers_pretax_sales_total BIGINT
    )
AS $$
BEGIN

    -- Calculate the total customer expenses for a given case
    -- This will include any contracts that have an invoice attached to them
    WITH expenses AS (
        SELECT
            invoice.funeral_home_case_id,
            SUM(COALESCE(posting.debit, 0) - COALESCE(posting.credit, 0)) AS total,
            SUM(CASE WHEN posting.is_tax THEN COALESCE(posting.debit, 0) - COALESCE(posting.credit, 0) ELSE 0 END) AS taxes
        FROM entity AS customer
        JOIN case_entity AS customer_case
            ON customer.id = customer_case.entity_id
        JOIN invoice
            ON invoice.customer_id = customer.id
            AND invoice.funeral_home_case_id = _funeral_home_case_id
        JOIN ledger.journal AS journal
            ON journal.invoice_id = invoice.id
        JOIN ledger.posting AS posting
            ON posting.journal_id = journal.id
            AND posting.owner = 'FH'
            AND posting.customer_id = customer.id    
        JOIN ledger.account AS account
            ON account.code = posting.account
            AND account.name = 'A/R'
        JOIN funeral_home_case AS fh_case
            ON fh_case.id = _funeral_home_case_id
        -- If this invoice is tied to a contract revision, find the one it is tied to
        LEFT JOIN product.contract_revision AS inv_revision
            ON inv_revision.invoice_id = invoice.id
        -- If this case has a contract, find it
        LEFT JOIN product.contract AS contract
            ON contract.funeral_home_case_id = invoice.funeral_home_case_id
        -- get the latest revision for this contract (if there is a contract)
        LEFT JOIN product.contract_revision AS latest_revision
            ON latest_revision.id = contract.latest_revision_id
        WHERE customer_case.gather_case_id = fh_case.gather_case_id
            AND customer.type = 'customer'
            AND journal.type = 'INVOICE'
            AND journal.reversed_time is null
            AND posting.is_reversal = false
            AND invoice.status = 'draft'
            -- If this invoice is tied to a contract only pull its transactions if it is tied to the latest revision
            AND (inv_revision.id IS NULL OR inv_revision.id = latest_revision.id)
        GROUP BY invoice.funeral_home_case_id
    ),

    -- Get the total of all contracts that are not currently tied to an invoice
    contracts AS (
        SELECT
            contract.funeral_home_case_id,
            SUM(COALESCE(contract.sub_total, 0) + COALESCE(contract.tax_total, 0))::BIGINT AS total,
            SUM(COALESCE(contract.tax_total, 0))::BIGINT AS taxes
        FROM product.contract AS contract
        JOIN product.contract_revision AS revision
            ON revision.id = contract.latest_revision_id
        WHERE contract.funeral_home_case_id = _funeral_home_case_id
            -- Only contracts that aren't invoiced
            AND revision.invoice_id IS NULL
        GROUP BY contract.funeral_home_case_id
    ),

    case_sale_category AS (
        -- Get all of the contract items that were added for each revision
        --  Added contract items get a multiplier of positive 1
        SELECT
          (item.list_price + item.price_adjustment + item.tax_total)*1 AS amount,
          (item.list_price + item.price_adjustment)*1 AS pretax_amount,
          item.category
        FROM product.contract AS contract
        JOIN product.contract_revision AS rev
            ON rev.contract_id = contract.id
        JOIN product.contract_item AS item
            ON item.insert_revision = rev.id
        WHERE contract.funeral_home_case_id = _funeral_home_case_id

        UNION ALL

        -- Get all of the contract items that were deleted for each revision
        --  Deleted contract items get a multiplier of negative 1
        SELECT
          (item.list_price + item.price_adjustment + item.tax_total)*-1 AS amount,
          (item.list_price + item.price_adjustment)*-1 AS pretax_amount,
          item.category
        FROM product.contract AS contract
        JOIN product.contract_revision AS rev
            ON rev.contract_id = contract.id
        JOIN product.contract_item AS item
            ON item.delete_revision = rev.id
        WHERE contract.funeral_home_case_id = _funeral_home_case_id

        UNION ALL

        -- Get all of the invoice items added outside the statement
        SELECT
          (invoice.amount_due + invoice.sales_tax) AS amount,
          invoice.amount_due AS pretax_amount,
          invoice.product_category AS category
        FROM invoice
        WHERE invoice.funeral_home_case_id = _funeral_home_case_id
          -- remove the invoice record for the statement (if it has been frozen)
          AND invoice.description NOT ILIKE 'Invoice for Case UUID%'
          AND invoice.status != 'void' -- Don't return voided invoices
          AND invoice.product_category IS NOT NULL
    ),

    -- Get the category totals for sales on the case
    sales_by_category AS (
      SELECT
        SUM(CASE
            WHEN sale.category::product.category_group = 'cash_advance'
                THEN sale.amount
            ELSE 0
        END)::BIGINT AS cashadv_amount,
        SUM(CASE
            WHEN sale.category::product.category_group = 'merchandise'
                THEN sale.amount
            ELSE 0
        END)::BIGINT AS merch_amount,
        SUM(CASE
            WHEN sale.category::product.category_group = 'professional_services'
                THEN sale.amount
            ELSE 0
        END)::BIGINT AS proserve_amount,
        SUM(CASE
            WHEN sale.category::product.category_group = 'cash_advance'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS cashadv_pretax_amount,
        SUM(CASE
            WHEN sale.category::product.category_group = 'merchandise'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS merch_pretax_amount,
        SUM(CASE
            WHEN sale.category::product.category_group = 'professional_services'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS proserve_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'care_of_loved_one'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS care_of_loved_one_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'transportation'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS transportation_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'equipment_facilities_staff'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS use_of_facilities_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'casket'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS casket_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'urn'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS urn_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'vault'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS vault_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'cemetery'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS cemetery_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'memorial'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS memorial_pretax_amount,
        SUM(CASE
            WHEN sale.category = 'flowers'
                THEN sale.pretax_amount
            ELSE 0
        END)::BIGINT AS flowers_pretax_amount
      FROM case_sale_category AS sale
    ),

    -- Get the total that is payed (and in the ledger)
    payments AS (
        SELECT
            payment.funeral_home_case_id,
            SUM(COALESCE(posting.credit, 0) - COALESCE(posting.debit, 0)) AS total
        FROM entity AS customer
        JOIN case_entity AS customer_case
            ON customer.id = customer_case.entity_id
        JOIN payment
            ON payment.customer_id = customer.id
            AND payment.funeral_home_case_id = _funeral_home_case_id
        JOIN payment_gather_payment pgp
            ON pgp.payment_id = payment.id
        JOIN ledger.journal AS journal
            ON journal.pgp_id = pgp.id
        JOIN ledger.posting AS posting
            ON posting.journal_id = journal.id
            AND posting.owner = 'FH'
            AND posting.customer_id = customer.id
        JOIN ledger.account AS account
            ON account.code = posting.account
            AND account.name = 'A/R'
        JOIN funeral_home_case AS fh_case
            ON fh_case.id = _funeral_home_case_id
        WHERE customer_case.gather_case_id = fh_case.gather_case_id
            AND customer.type = 'customer'
            AND journal.type = 'PAYMENT'
            AND journal.reversed_time is null
            AND posting.is_reversal = false
        GROUP BY payment.funeral_home_case_id
    ),

    -- Get the total that is proposed or requested
    proposed AS (
        SELECT
            payment.funeral_home_case_id,
            SUM(COALESCE(gather_payment.amount, payment.amount)) AS total
        FROM entity AS customer
        JOIN case_entity AS customer_case
            ON customer.id = customer_case.entity_id
        JOIN payment
            ON payment.customer_id = customer.id
            AND payment.funeral_home_case_id = _funeral_home_case_id
        LEFT JOIN LATERAL (
          SELECT * FROM (
            SELECT 
              pgp.id,
              pgp.amount,
              COALESCE(gp.payment_status, pgp.status, 'proposed') as status,
              ROW_NUMBER() OVER (
                PARTITION BY pgp.payment_id 
                ORDER BY 
                  CASE WHEN COALESCE(gp.payment_status, pgp.status) = 'refunded' THEN 3
                  WHEN COALESCE(gp.payment_status, pgp.status) not in ('requested', 'proposed') THEN 1
                  ELSE 2 END,
                  pgp.id ASC
              ) as rn,
              FIRST_VALUE(COALESCE(gp.payment_status, pgp.status)) OVER (
                PARTITION BY pgp.payment_id 
                ORDER BY 
                  CASE WHEN COALESCE(gp.payment_status, pgp.status) = 'refunded' THEN 2 ELSE 1 END,
                  pgp.id DESC
              ) as main_status
            FROM payment_gather_payment pgp
            LEFT JOIN gather_payment gp ON gp.id = pgp.gather_payment_id
            WHERE pgp.payment_id = payment.id
            ORDER BY pgp.id ASC) AS transactions
            WHERE transactions.rn = 1 OR (transactions.status = 'refunded' and transactions.main_status != 'failed')
        ) AS gather_payment ON true
        LEFT JOIN LATERAL(
          SELECT j.pgp_id
          FROM ledger.journal j
          WHERE j.reversed_by IS NULL
            AND NOT EXISTS (
              SELECT 1
              FROM ledger.posting p2
              WHERE p2.journal_id = j.id
                AND p2.is_reversal = true
            )
            AND j.pgp_id = gather_payment.id
          GROUP BY j.pgp_id
        ) uj ON true
        JOIN funeral_home_case AS fh_case
            ON fh_case.id = _funeral_home_case_id
        WHERE customer_case.gather_case_id = fh_case.gather_case_id
            AND customer.type = 'customer'
            AND (gather_payment.status IN ('proposed', 'requested', 'pending', 'refunded')
            OR gather_payment.status IS NULL)
            AND uj.pgp_id IS NULL
        GROUP BY payment.funeral_home_case_id
    ),
-- Get the total of all statement-level adjustments
    statement_adjustments AS (
      SELECT
        SUM(amount) AS total
      FROM (
        -- Get all of the contract items that were added for each revision
        --  Added contract items get a multiplier of positive 1
        SELECT
          CASE
            WHEN ci.type = 'contract_discount' THEN ci.list_price
            WHEN ci.type = 'package_discount' THEN ci.list_price
            ELSE 0
          END * 1 AS amount
        FROM product.contract AS contract
        JOIN product.contract_revision AS revision ON revision.contract_id = contract.id
        JOIN product.contract_item AS ci ON ci.insert_revision = revision.id
        WHERE contract.funeral_home_case_id = _funeral_home_case_id

        UNION ALL

        -- Get all of the contract items that were deleted for each revision
        --  Deleted contract items get a multiplier of negative 1
        SELECT
          CASE
            WHEN ci.type = 'contract_discount' THEN ci.list_price
            WHEN ci.type = 'package_discount' THEN ci.list_price
            ELSE 0
          END * -1 AS amount
        FROM product.contract AS contract
        JOIN product.contract_revision AS revision ON revision.contract_id = contract.id
        JOIN product.contract_item AS ci ON ci.delete_revision = revision.id
        WHERE contract.funeral_home_case_id = _funeral_home_case_id
      ) AS adjustments
    ),

    -- Bring all the totals together
    totals AS (
        SELECT
            COALESCE(expenses.total, 0) + COALESCE(contracts.total, 0) AS expense,
            COALESCE(proposed.total, 0) AS proposed,
            COALESCE(payments.total, 0) AS collected,
            COALESCE(expenses.taxes, 0) + COALESCE(contracts.taxes, 0) AS taxes,
            COALESCE(statement_adjustments.total, 0) AS statement_adjustments_total,
            COALESCE(sales_by_category.cashadv_amount, 0) AS cashadv_sales_total,
            COALESCE(sales_by_category.cashadv_pretax_amount, 0) AS cashadv_pretax_sales_total,
            COALESCE(sales_by_category.merch_amount, 0) AS merch_sales_total,
            COALESCE(sales_by_category.merch_pretax_amount, 0) AS merch_pretax_sales_total,
            COALESCE(sales_by_category.proserve_amount, 0) AS proserve_sales_total,
            COALESCE(sales_by_category.proserve_pretax_amount, 0) AS proserve_pretax_sales_total,
            COALESCE(sales_by_category.care_of_loved_one_pretax_amount, 0) AS care_of_loved_one_pretax_sales_total,
            COALESCE(sales_by_category.transportation_pretax_amount, 0) AS transportation_pretax_sales_total,
            COALESCE(sales_by_category.use_of_facilities_pretax_amount, 0) AS use_of_facilities_pretax_sales_total,
            COALESCE(sales_by_category.casket_pretax_amount, 0) AS casket_pretax_sales_total,
            COALESCE(sales_by_category.urn_pretax_amount, 0) AS urn_pretax_sales_total,
            COALESCE(sales_by_category.vault_pretax_amount, 0) AS vault_pretax_sales_total,
            COALESCE(sales_by_category.cemetery_pretax_amount, 0) AS cemetery_pretax_sales_total,
            COALESCE(sales_by_category.memorial_pretax_amount, 0) AS memorial_pretax_sales_total,
            COALESCE(sales_by_category.flowers_pretax_amount, 0) AS flowers_pretax_sales_total
        FROM funeral_home_case AS fh_case
        LEFT JOIN proposed ON proposed.funeral_home_case_id = fh_case.id
        LEFT JOIN payments ON payments.funeral_home_case_id = fh_case.id
        LEFT JOIN expenses ON expenses.funeral_home_case_id = fh_case.id
        LEFT JOIN contracts ON contracts.funeral_home_case_id = fh_case.id
        LEFT JOIN statement_adjustments ON TRUE
        LEFT JOIN sales_by_category ON TRUE
        WHERE fh_case.id = _funeral_home_case_id
    )

    -- Update the case
    UPDATE funeral_home_case SET
        expense_total = totals.expense,
        collected_total = totals.collected,
        proposed_total = totals.proposed,
        tax_total = totals.taxes,
        statement_adjustments_total = totals.statement_adjustments_total,
        merch_pretax_sales_total = totals.merch_pretax_sales_total,
        proserve_pretax_sales_total = totals.proserve_pretax_sales_total,
        cashadv_pretax_sales_total = totals.cashadv_pretax_sales_total,
        care_of_loved_one_pretax_sales_total = totals.care_of_loved_one_pretax_sales_total,
        transportation_pretax_sales_total = totals.transportation_pretax_sales_total,
        use_of_facilities_pretax_sales_total = totals.use_of_facilities_pretax_sales_total,
        casket_pretax_sales_total = totals.casket_pretax_sales_total,
        urn_pretax_sales_total = totals.urn_pretax_sales_total,
        vault_pretax_sales_total = totals.vault_pretax_sales_total,
        cemetery_pretax_sales_total = totals.cemetery_pretax_sales_total,
        memorial_pretax_sales_total = totals.memorial_pretax_sales_total,
        flowers_pretax_sales_total = totals.flowers_pretax_sales_total
    FROM totals
    WHERE funeral_home_case.id = _funeral_home_case_id;

    -- Return the results as a table
    RETURN QUERY SELECT
        fh_case.id AS funeral_home_case_id,
        fh_case.uuid,
        fh_case.expense_total,
        fh_case.collected_total,
        fh_case.proposed_total,
        fh_case.tax_total,
        fh_case.statement_adjustments_total,
        fh_case.merch_pretax_sales_total,
        fh_case.proserve_pretax_sales_total,
        fh_case.cashadv_pretax_sales_total,
        fh_case.care_of_loved_one_pretax_sales_total,
        fh_case.transportation_pretax_sales_total,
        fh_case.use_of_facilities_pretax_sales_total,
        fh_case.casket_pretax_sales_total,
        fh_case.urn_pretax_sales_total,
        fh_case.vault_pretax_sales_total,
        fh_case.cemetery_pretax_sales_total,
        fh_case.memorial_pretax_sales_total,
        fh_case.flowers_pretax_sales_total
    FROM funeral_home_case AS fh_case
    WHERE fh_case.id = _funeral_home_case_id;

END; $$
LANGUAGE PLPGSQL;

CREATE FUNCTION product.calculate_contract_tax(sub_total BIGINT, in_tax_rate_id INTEGER) RETURNS BIGINT AS $calculate_contract_tax$
  -- Calculate contract tax by applying the tax brackets selected
  -- This function also exists in JS called "applyTaxRate" for determining per-item tax
  DECLARE
    bracket RECORD;
    tax_total BIGINT;
  BEGIN
      SELECT
        SUM(
          (CASE
            WHEN sub_total - minimum < 0 THEN 0
            WHEN maximum IS NOT NULL AND sub_total - minimum > maximum THEN maximum - minimum
            ELSE sub_total - minimum
          END) * (rate/100)
        )
      INTO tax_total
      FROM product.tax_rate_bracket
      WHERE tax_rate_id = in_tax_rate_id
      GROUP BY
        tax_rate_id;
    RETURN tax_total;
  END;
$calculate_contract_tax$ LANGUAGE plpgsql;

CREATE FUNCTION product.calculate_total(contract_id_updated INTEGER) RETURNS VOID AS $calculate_total$
  -- For each contract updated: get the sub_total & tax_total by suming all the non-deleted contract_item records
  -- Update the product.contract table with these values
  BEGIN
      WITH totals AS (
        SELECT
          contract.id AS contract_id,
          contract.taxation_method,
          SUM(ci.list_price::BIGINT + ci.price_adjustment::BIGINT)::BIGINT AS sub_total,
          SUM(ci.tax_total)::BIGINT AS tax_total
        FROM product.contract AS contract
        LEFT JOIN product.contract_item AS ci
          ON ci.contract_id = contract.id
          AND ci.delete_revision IS NULL
        WHERE contract.id = contract_id_updated
        GROUP BY
          contract.id
      )
      UPDATE product.contract AS contract
        SET
          sub_total = COALESCE(totals.sub_total, 0),
          tax_total = CASE
            WHEN contract.taxation_method = 'per_item_basis' AND totals.tax_total IS NOT NULL THEN totals.tax_total
            WHEN contract.taxation_method = 'contract_basis' AND totals.sub_total IS NOT NULL THEN product.calculate_contract_tax(totals.sub_total, tax_rate_id) 
            ELSE 0
          END
      FROM totals
      WHERE totals.contract_id = contract.id
      ;

      PERFORM set_case_totals(contract.funeral_home_case_id)
      FROM product.contract AS contract
      WHERE contract.id = contract_id_updated;
  END;
$calculate_total$ LANGUAGE plpgsql;

CREATE FUNCTION product.calculate_total_from_contract() RETURNS TRIGGER AS $calculate_total_from_contract$
  BEGIN
    PERFORM product.calculate_total(NEW.id);

    RETURN NULL; -- return ignored
  END;
$calculate_total_from_contract$ LANGUAGE plpgsql;

CREATE TRIGGER contract_taxation_change
  AFTER UPDATE OF taxation_method, tax_rate_id ON product.contract
  FOR EACH ROW EXECUTE PROCEDURE product.calculate_total_from_contract();

CREATE TABLE product.contract_viewer (
  contract_id               INTEGER NOT NULL REFERENCES product.contract(id) ON DELETE CASCADE,
  user_profile_id           INTEGER NOT NULL REFERENCES user_profile(id) ON DELETE CASCADE,
  -- is_editor                 BOOLEAN NOT NULL,
  PRIMARY KEY (contract_id, user_profile_id)
);

CREATE VIEW product.product_ux AS
SELECT
  p.id,
  p.name,
  p.description,
  p.sku,
  p.manufacturer_id,
  p.category,
  p.model_number,
  p.external_link,
  p.funeral_home_id,
  p.is_package_exclusive,
  p.is_hidden,
  p.featured_rank,
  p.category_rank,
  p.photos,
  p.tags,
  p.pricing_model,
  p.cost,
  p.base_price,
  p.base_quantity,
  p.var_price,
  p.var_increment,
  p.var_increment_units,
  p.var_max_quantity,
  p.var_default_quantity,
  p.tax_rate_id,
  p.asset_type,
  p.cloned_from,
  p.cloned_time,
  p.created_by,
  p.created_time,
  p.updated_by,
  p.updated_time,
  p.deleted_by,
  p.deleted_time,
  p.is_always_displayed,
  p.use_na_when_always_displayed,
  p.display_model_number,
  p.display_manufacturer,
  p.display_tags,
  p.persistent_contract_text,
  p.bold_contract_text,
  p.underline_contract_text,
  p.indent_contract_text,
  p.show_on_website,
  p.show_price_on_website,
  tax.name AS tax_rate_name,
  tax.description AS tax_rate_description,
  mfr.name AS manufacturer_name,
  mfr.external_link AS manufacturer_link
FROM product.product AS p
LEFT JOIN product.tax_rate AS tax
  ON tax.id = p.tax_rate_id
LEFT JOIN product.manufacturer AS mfr
  ON mfr.id = p.manufacturer_id
ORDER BY p.category_rank, p.created_time
;

-- END APP-520

-- APP-1093
CREATE TABLE product.contract_disclaimer (
  id                    SERIAL PRIMARY KEY,
  funeral_home_id       INTEGER NOT NULL REFERENCES public.funeral_home(id) ON DELETE CASCADE,
  disclaimer            TEXT NOT NULL,
  fh_cloned_from        INTEGER REFERENCES product.contract_disclaimer(id) ON DELETE SET NULL,
  fh_cloned_time        TIMESTAMP WITH TIME ZONE
);

CREATE TABLE product.contract_disclaimer_reason (
  disclaimer_id         INTEGER NOT NULL REFERENCES product.contract_disclaimer(id) ON DELETE CASCADE,
  contract_id           INTEGER NOT NULL REFERENCES product.contract(id) ON DELETE CASCADE,
  reason                TEXT NOT NULL,
  PRIMARY KEY (disclaimer_id, contract_id)
);
-- END APP-1093

CREATE FUNCTION product.clone_gpl_products(src_funeral_home_id INTEGER, dest_funeral_home_id INTEGER, _category product.category) RETURNS VOID 
AS $clone_gpl_products$
BEGIN

  -- clone over products and use destination's default_item_tax_rate if set
  WITH dest_options AS (
    SELECT COALESCE(dest_opts.default_item_tax_rate, src_opts.default_item_tax_rate) AS default_item_tax_rate
    FROM product.contract_options AS dest_opts
    LEFT JOIN product.contract_options AS src_opts
      ON src_opts.funeral_home_id = src_funeral_home_id
    WHERE dest_opts.funeral_home_id = dest_funeral_home_id
  )
  INSERT INTO product.product (
    name,
    description,
    sku,
    manufacturer_id,
    category,
    model_number,
    external_link,
    funeral_home_id,
    is_package_exclusive,
    is_hidden,
    category_rank,
    featured_rank,
    photos,
    tags,
    pricing_model,
    cost,
    base_price,
    base_quantity,
    var_price,
    var_increment,
    var_increment_units,
    var_max_quantity,
    var_default_quantity,
    tax_rate_id,
    asset_type,
    cloned_from,
    cloned_time,
    created_by,
    created_time,
    updated_by,
    updated_time,
    deleted_by,
    deleted_time,
    is_always_displayed,
    use_na_when_always_displayed,
    display_model_number,
    display_manufacturer,
    display_tags,
    persistent_contract_text,
    bold_contract_text,
    underline_contract_text,
    indent_contract_text,
    show_on_website,
    show_price_on_website,
    fh_cloned_from,
    fh_cloned_time
  )
  SELECT
    name,
    description,
    sku,
    manufacturer_id,
    category,
    model_number,
    external_link,
    dest_funeral_home_id AS funeral_home_id,
    is_package_exclusive,
    is_hidden,
    category_rank,
    featured_rank,
    photos,
    tags,
    pricing_model,
    cost,
    base_price,
    base_quantity,
    var_price,
    var_increment,
    var_increment_units,
    var_max_quantity,
    var_default_quantity,
    CASE WHEN tax_rate_id IS NULL THEN null ELSE COALESCE(dest_options.default_item_tax_rate, tax_rate_id) END AS tax_rate_id,
    asset_type,
    cloned_from,
    cloned_time,
    created_by,
    created_time,
    updated_by,
    updated_time,
    deleted_by,
    deleted_time,
    is_always_displayed,
    use_na_when_always_displayed,
    display_model_number,
    display_manufacturer,
    display_tags,
    persistent_contract_text,
    bold_contract_text,
    underline_contract_text,
    indent_contract_text,
    show_on_website,
    show_price_on_website,
    id AS fh_cloned_from,
    NOW() AS fh_cloned_time
  FROM product.product
  LEFT JOIN dest_options ON TRUE
  WHERE deleted_time IS NULL
    AND funeral_home_id = src_funeral_home_id
    AND (_category IS NULL OR category = _category)
  ;

END;
$clone_gpl_products$
LANGUAGE plpgsql VOLATILE;

-- APP-1166
CREATE FUNCTION product.clone_gpl(src_funeral_home_id INTEGER, dest_funeral_home_id INTEGER) RETURNS VOID 
AS $clone_gpl$
DECLARE
   _columns TEXT;
BEGIN

  -- clone products --
  PERFORM product.clone_gpl_products(src_funeral_home_id, dest_funeral_home_id, NULL);

  -- clone packages --
  -- Do not clone replaces_package or original_package because those point to deleted packages that we do not need to clone
  _columns := string_agg(column_name, ',')
  FROM (
    SELECT column_name FROM information_schema.columns WHERE table_schema = 'product' AND table_name = 'package' AND column_name NOT IN ('id', 'funeral_home_id', 'fh_cloned_from', 'fh_cloned_time', 'replaces_package', 'original_package')
  ) x;
  EXECUTE
  'INSERT INTO product.package ' || '(' || _columns || ', funeral_home_id, fh_cloned_from, fh_cloned_time) '
  'SELECT ' || _columns || ', ' || dest_funeral_home_id || ', id, NOW() ' ||
  'FROM product.package WHERE deleted_time IS NULL AND funeral_home_id = ' || src_funeral_home_id;

  -- clone package items --
  -- Don't clone package items where all item options have deleted products/sub-packages
  INSERT INTO product.package_item
    (package_id, name, max_selections, category, fh_cloned_from, fh_cloned_time)
  WITH valid_src_pkg_items AS (
    SELECT DISTINCT
      srcItem.*
    FROM product.package_item AS srcItem
    JOIN product.package AS srcPkg
      ON srcPkg.id = srcItem.package_id
      AND srcPkg.funeral_home_id = src_funeral_home_id
      AND srcPkg.deleted_time IS NULL
    JOIN product.package_item_option AS srcItemOpt
      ON srcItemOpt.package_item_id = srcItem.id
    LEFT JOIN product.product AS destProduct
      ON destProduct.fh_cloned_from = srcItemOpt.product_id
      AND destProduct.funeral_home_id = dest_funeral_home_id
    LEFT JOIN product.package AS destPkg
      ON destPkg.fh_cloned_from = srcItemOpt.sub_package_id
      AND destPkg.funeral_home_id = dest_funeral_home_id
    WHERE destProduct.id IS NOT NULL OR destPkg.id IS NOT NULL
  )
  SELECT
    destPackage.id AS package_id,
    srcItem.name,
    srcItem.max_selections,
    srcItem.category,
    srcItem.id AS fh_cloned_from,
    NOW() AS fh_cloned_time
  FROM valid_src_pkg_items AS srcItem
  JOIN product.package AS destPackage
    ON destPackage.funeral_home_id = dest_funeral_home_id
    AND destPackage.fh_cloned_from = srcItem.package_id
  ORDER BY srcItem.id
  ;

  -- clone package item options --
  INSERT INTO product.package_item_option (package_item_id, product_id, sub_package_id, fh_cloned_from, fh_cloned_time)
  SELECT
    destItem.id AS package_item_id,
    destProduct.id AS product_id,
    destSubPkg.id AS sub_package_id,
    srcItemOpt.id AS fh_cloned_from,
    NOW() AS fh_cloned_time
  FROM product.package_item_option AS srcItemOpt
  JOIN product.package_item AS srcItem
    ON srcItem.id = srcItemOpt.package_item_id
  JOIN product.package AS srcPkg
    ON srcPkg.funeral_home_id = src_funeral_home_id
    AND srcPkg.id = srcItem.package_id
    AND srcPkg.deleted_time IS NULL
  JOIN product.package AS destPkg
    ON destPkg.funeral_home_id = dest_funeral_home_id
    AND destPkg.fh_cloned_from = srcPkg.id
  JOIN product.package_item AS destItem
    ON destItem.fh_cloned_from = srcItemOpt.package_item_id
    AND destItem.package_id = destPkg.id
  LEFT JOIN product.product AS destProduct
    ON destProduct.fh_cloned_from = srcItemOpt.product_id
    AND destProduct.funeral_home_id = dest_funeral_home_id
  LEFT JOIN product.package AS destSubPkg
    ON destSubPkg.fh_cloned_from = srcItemOpt.sub_package_id
    AND destSubPkg.funeral_home_id = dest_funeral_home_id
  WHERE destProduct.id IS NOT NULL OR destSubPkg.id IS NOT NULL
  ;

  -- clone contract_options --
  -- If contract_options already exist for destination FH, overwrite everything except default_item_tax_rate (unless null)
  INSERT INTO product.contract_options (
    funeral_home_id,
    legal_top,
    legal_bottom,
    legal_pro_services,
    legal_merchandise,
    legal_cash_advances,
    legal_contract_disclaimer,
    legal_invoice,
    default_taxation_method,
    default_contract_tax_rate,
    default_item_tax_rate,
    include_fh_license,
    include_fh_extra_field,
    fh_extra_field_name,
    is_fh_extra_field_req,
    include_fam_address,
    include_fam_phone,
    include_fam_email,
    include_fam_extra_field,
    fam_extra_field_name,
    is_fam_extra_field_req,
    hide_package_item_prices,
    print_page_size,
    use_five_category_groups,
    use_two_category_groups,
    package_view,
    equal_contract_spacing,
    fh_cloned_from,
    fh_cloned_time
  )
  SELECT
    dest_funeral_home_id AS funeral_home_id,
    legal_top,
    legal_bottom,
    legal_pro_services,
    legal_merchandise,
    legal_cash_advances,
    legal_contract_disclaimer,
    legal_invoice,
    default_taxation_method,
    default_contract_tax_rate,
    default_item_tax_rate,
    include_fh_license,
    include_fh_extra_field,
    fh_extra_field_name,
    is_fh_extra_field_req,
    include_fam_address,
    include_fam_phone,
    include_fam_email,
    include_fam_extra_field,
    fam_extra_field_name,
    is_fam_extra_field_req,
    hide_package_item_prices,
    print_page_size,
    use_five_category_groups,
    use_two_category_groups,
    package_view,
    equal_contract_spacing,
    funeral_home_id AS fh_cloned_from,
    NOW() AS fh_cloned_time
  FROM product.contract_options
  WHERE funeral_home_id = src_funeral_home_id
  ON CONFLICT ON CONSTRAINT contract_options_pkey
  DO UPDATE SET
    funeral_home_id = dest_funeral_home_id,
    legal_top = EXCLUDED.legal_top,
    legal_bottom = EXCLUDED.legal_bottom,
    legal_pro_services = EXCLUDED.legal_pro_services,
    legal_merchandise = EXCLUDED.legal_merchandise,
    legal_cash_advances = EXCLUDED.legal_cash_advances,
    legal_contract_disclaimer = EXCLUDED.legal_contract_disclaimer,
    legal_invoice = EXCLUDED.legal_invoice,
    default_taxation_method = EXCLUDED.default_taxation_method,
    default_contract_tax_rate = EXCLUDED.default_contract_tax_rate,
    default_item_tax_rate = COALESCE(product.contract_options.default_item_tax_rate, EXCLUDED.default_item_tax_rate),
    include_fh_license = EXCLUDED.include_fh_license,
    include_fh_extra_field = EXCLUDED.include_fh_extra_field,
    fh_extra_field_name = EXCLUDED.fh_extra_field_name,
    is_fh_extra_field_req = EXCLUDED.is_fh_extra_field_req,
    include_fam_address = EXCLUDED.include_fam_address,
    include_fam_phone = EXCLUDED.include_fam_phone,
    include_fam_email = EXCLUDED.include_fam_email,
    include_fam_extra_field = EXCLUDED.include_fam_extra_field,
    fam_extra_field_name = EXCLUDED.fam_extra_field_name,
    is_fam_extra_field_req = EXCLUDED.is_fam_extra_field_req,
    hide_package_item_prices = EXCLUDED.hide_package_item_prices,
    print_page_size = EXCLUDED.print_page_size,
    use_five_category_groups = EXCLUDED.use_five_category_groups,
    use_two_category_groups = EXCLUDED.use_two_category_groups,
    package_view = EXCLUDED.package_view,
    equal_contract_spacing = EXCLUDED.equal_contract_spacing,
    fh_cloned_from = src_funeral_home_id,
    fh_cloned_time = NOW()
  ;

  -- clone contract_disclaimers --
  INSERT INTO product.contract_disclaimer (funeral_home_id, disclaimer, fh_cloned_from, fh_cloned_time)
  SELECT dest_funeral_home_id, disclaimer, id, NOW()
  FROM product.contract_disclaimer
  WHERE funeral_home_id = src_funeral_home_id;

  -- clone product suppliers --
  INSERT INTO product.supplier_funeralhome (supplier_id, funeral_home_id, category, fh_cloned_from, fh_cloned_time)
  SELECT
    supplier_id,
    dest_funeral_home_id AS funeral_home_id,
    category,
    src_funeral_home_id AS fh_cloned_from,
    NOW() AS fh_cloned_time
  FROM product.supplier_funeralhome
  WHERE funeral_home_id = src_funeral_home_id;

END;
$clone_gpl$
LANGUAGE plpgsql VOLATILE;
-- END APP-1166



-- UX Views
CREATE VIEW service_template_ux AS SELECT DISTINCT ON (st.id)
  st.id,
  st.name,
  st.key,
  st.description,
  st.created_by,
  st.created_time,
  st.deactivated_by,
  st.deactivated_time,
  st.updated_by,
  st.updated_time,
  st.all_funeral_homes,
  count(DISTINCT dsd_with_order.service_template_detail_id)::INTEGER AS service_detail_count,
  CASE
    WHEN count(DISTINCT dsd_with_order.service_template_detail_id) = 0
      THEN '[]'::JSON
      ELSE json_agg(
         dsd_with_order ORDER BY dsd_with_order.detail_order
      )
    END
    AS service_details
  FROM service_template AS st
  LEFT JOIN (
      SELECT DISTINCT
        dsd.*,
        std.detail_order AS detail_order,
        std.id AS service_template_detail_id,
        std.service_template_id AS service_template_id
      FROM
        default_service_detail AS dsd
      JOIN
        service_template_detail AS std
      ON
        std.default_service_detail_id = dsd.id
      WHERE
        std.deactivated_time IS NULL
      GROUP BY
        std.id,
        dsd.id,
        dsd.title,
        dsd.key,
        dsd.explainer_text,
        dsd.can_edit_title_by_user,
        dsd.can_sort_fields_by_user,
        dsd.can_be_deleted_by_user,
        dsd.can_user_add_music,
        dsd.add_music_label,
        dsd.can_user_add_person,
        dsd.add_person_label,
        dsd.can_user_add_text,
        dsd.add_text_label,
        dsd.can_be_deleted,
        dsd.data,
        dsd.created_by,
        dsd.created_time,
        dsd.updated_by,
        dsd.updated_time
      ORDER BY
        std.detail_order
  ) AS dsd_with_order
  ON
    dsd_with_order.service_template_id = st.id
  GROUP BY
    st.id,
    st.name,
    st.key,
    st.description,
    st.created_by,
    st.created_time,
    st.deactivated_by,
    st.deactivated_time,
    st.updated_by,
    st.updated_time
;

-- calendar taken from https://medium.com/@duffn/creating-a-date-dimension-table-in-postgresql-af3f8e2941ac
CREATE TABLE calendar
(
  calendar_id              INT NOT NULL,
  date_actual              DATE NOT NULL,
  epoch                    BIGINT NOT NULL,
  day_suffix               TEXT,
  day_name                 TEXT,
  day_of_week              INT NOT NULL,
  day_of_month             INT NOT NULL,
  day_of_quarter           INT NOT NULL,
  day_of_year              INT NOT NULL,
  week_of_month            INT NOT NULL,
  week_of_year             INT NOT NULL,
  week_of_year_iso         TEXT,
  month_actual             INT NOT NULL,
  month_name               TEXT,
  month_name_abbreviated   TEXT,
  quarter_actual           INT NOT NULL,
  quarter_name             TEXT,
  year_actual              INT NOT NULL,
  first_day_of_week        DATE NOT NULL,
  last_day_of_week         DATE NOT NULL,
  first_day_of_month       DATE NOT NULL,
  last_day_of_month        DATE NOT NULL,
  first_day_of_quarter     DATE NOT NULL,
  last_day_of_quarter      DATE NOT NULL,
  first_day_of_year        DATE NOT NULL,
  last_day_of_year         DATE NOT NULL,
  mmyyyy                   TEXT,
  mmddyyyy                 TEXT,
  weekend_indr             BOOLEAN NOT NULL
);

ALTER TABLE public.calendar ADD CONSTRAINT calendar_calendar_id_pk PRIMARY KEY (calendar_id);

CREATE INDEX calendar_date_actual_idx
  ON calendar(date_actual);

CREATE INDEX calendar_month_actual_idx
  ON calendar(month_actual);

CREATE INDEX calendar_year_actual_idx
  ON calendar(year_actual);

-- APP-872 doc upload/download
CREATE TYPE doc_pdf_status AS ENUM (
  'none',
  'success',
  'processed: no Gather fields found',
  'not needed',
  'error: general',
  'error: failed to create PDF',
  'error: failed to parse PDF fields',
  'error: signer does not have a signature or initial field.'
);

CREATE TYPE public.doc_category AS ENUM ('general', 'form_dd214');

CREATE TABLE public.doc (
  id                        SERIAL PRIMARY KEY,
  s3_file_id                INTEGER NOT NULL REFERENCES public.s3_file(id),
  parent_doc_id             INTEGER, -- if this is null than I am the oldest parent
  label                     TEXT ,
  is_private                BOOLEAN NOT NULL DEFAULT TRUE,
  icon                      TEXT,
  default_icon              TEXT,
  pdf_fields                TEXT[],
  pdf_status                doc_pdf_status NOT NULL DEFAULT 'none',
  is_esign_enabled          BOOLEAN NOT NULL DEFAULT FALSE,  -- Flag is true if there is one SIG field found in the PDF.
  pdf_invalid_fields        JSONB NOT NULL DEFAULT '[]'::jsonb,
  pdf_markup_fields         JSONB NOT NULL DEFAULT '[]'::jsonb,
  doc_category              public.doc_category NOT NULL DEFAULT 'general'
);


CREATE TABLE public.doc_funeral_home (
  doc_id                    INTEGER REFERENCES doc(id) ON DELETE CASCADE,
  funeral_home_id           INTEGER REFERENCES funeral_home(id) ON DELETE CASCADE,
  startup_rank              INTEGER DEFAULT NULL,
  sent_upload_notification  TIMESTAMP WITH TIME ZONE,
  CONSTRAINT doc_funeral_home_pkey PRIMARY KEY(doc_id, funeral_home_id)
);

CREATE TABLE public.doc_case_file (
  doc_id                    INTEGER NOT NULL REFERENCES doc(id) ON DELETE CASCADE,
  gather_case_id            INTEGER NOT NULL REFERENCES gather_case(id) ON DELETE CASCADE,
  task_component_id         INTEGER REFERENCES public.task_component(id),
  CONSTRAINT doc_case_pkey PRIMARY KEY(doc_id, gather_case_id)
);

CREATE TABLE public.doc_organization (
  doc_id                  INTEGER NOT NULL REFERENCES doc(id) ON DELETE CASCADE,
  organization_id         INTEGER NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  CONSTRAINT doc_org_pkey PRIMARY KEY(doc_id, organization_id)
);

  -- Store Case ID photos on the gather_case as a special, temporary S3 file.
CREATE TABLE public.case_id_photo (
  s3_file_id          INTEGER NOT NULL REFERENCES public.s3_file(id),
  gather_case_id      INTEGER NOT NULL REFERENCES public.gather_case(id),
  PRIMARY KEY(s3_file_id, gather_case_id)
);

CREATE TYPE public.fingerprint_type AS ENUM ('fingerprint',  'right_thumb',  'right_index_finger',  'right_middle_finger',  'right_ring_finger',  'right_pinky_finger',  'left_thumb',  'left_index_finger',  'left_middle_finger',  'left_ring_finger',  'left_pinky_finger',  'other_print',  'child_fingerprint',  'child_handprint',  'child_footprint',  'dog_pawprint',  'dog_noseprint',  'cat_pawprint',  'other_animal_print');

-- Fingerprint is a join table between case and s3_file
CREATE TABLE public.fingerprint (
  gather_case_id          INTEGER NOT NULL REFERENCES public.gather_case(id),
  s3_file_id              INTEGER NOT NULL REFERENCES public.s3_file(id),
  s3_orig_file_id         INTEGER NOT NULL REFERENCES public.s3_file(id),
  type                    public.fingerprint_type NOT NULL,
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  PRIMARY KEY(s3_file_id, gather_case_id)
);

-- START APP-948 - eSign

CREATE TYPE doc_packet_type AS ENUM ('fill_esign', 'fill_print', 'fill_in_person');
CREATE TYPE doc_packet_status AS ENUM ('started', 'printed', 'sent', 'signed');

CREATE TABLE doc_packet (
  id                      SERIAL PRIMARY KEY,
  gather_case_id          INTEGER NOT NULL REFERENCES gather_case(id) ON DELETE CASCADE,
  status                  doc_packet_status NOT NULL,
  type                    doc_packet_type NOT NULL,
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by              INTEGER NOT NULL REFERENCES user_profile(id),
  data_updated_time       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  data_updated_by         INTEGER NOT NULL REFERENCES user_profile(id),
  pdf_created_time        TIMESTAMP WITH TIME ZONE,
  pdf_created_by          INTEGER REFERENCES user_profile(id),
  pdf_final_file          TEXT,
  hellosign_id            TEXT,
  deleted_time            TIMESTAMP WITH TIME ZONE,
  deleted_by              INTEGER REFERENCES user_profile(id),
  notification_sent_time  TIMESTAMP WITH TIME ZONE
);

CREATE TABLE doc_packet_doc (
  id                    SERIAL PRIMARY KEY,
  doc_id                INTEGER NOT NULL REFERENCES doc(id) ON DELETE CASCADE,
  doc_packet_id         INTEGER NOT NULL REFERENCES doc_packet(id) ON DELETE CASCADE,
  field_data            JSONB NOT NULL DEFAULT '[]'::JSONB,
  UNIQUE (doc_id, doc_packet_id)
);

CREATE INDEX doc_packet_doc_doc_packet_idx ON doc_packet_doc(doc_packet_id);

CREATE TABLE doc_packet_signed_doc (
  doc_id                INTEGER NOT NULL REFERENCES doc(id) ON DELETE CASCADE,
  doc_packet_id         INTEGER NOT NULL REFERENCES doc_packet(id) ON DELETE CASCADE,
  PRIMARY KEY (doc_id, doc_packet_id)
);

CREATE TABLE doc_packet_contract (
  id                    SERIAL PRIMARY KEY,
  contract_id           INTEGER NOT NULL REFERENCES product.contract(id) ON DELETE CASCADE,
  doc_packet_id         INTEGER NOT NULL REFERENCES doc_packet(id) ON DELETE CASCADE,
  UNIQUE (contract_id, doc_packet_id)
);

CREATE TABLE doc_packet_signer (
  id                    SERIAL PRIMARY KEY,
  doc_packet_id         INTEGER NOT NULL REFERENCES doc_packet(id) ON DELETE CASCADE,
  person_id             INTEGER NOT NULL REFERENCES entity(id) ON DELETE CASCADE,
  hellosign_id          TEXT,
  hellosign_status      TEXT,
  hellosign_status_time TIMESTAMP WITH TIME ZONE,
  last_reminder_sent_time TIMESTAMP WITH TIME ZONE,
  UNIQUE (doc_packet_id, person_id)
);

CREATE TYPE signer_history_type AS ENUM ('send_signature_request','send_signature_reminder','update_signature');

CREATE TABLE doc_packet_signer_history (
  id                    SERIAL PRIMARY KEY,
  doc_packet_id         INTEGER NOT NULL REFERENCES doc_packet(id) ON DELETE CASCADE,
  person_id             INTEGER NOT NULL REFERENCES entity(id) ON DELETE CASCADE,
  email                 TEXT NOT NULL,  -- this email was the one that was sent on the request
  history_type          signer_history_type NOT NULL,
  sent_time             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE doc_packet_contract_signer (
  doc_packet_contract_id  INTEGER NOT NULL REFERENCES doc_packet_contract(id) ON DELETE CASCADE,
  doc_packet_signer_id    INTEGER NOT NULL REFERENCES doc_packet_signer(id) ON DELETE CASCADE,
  signer_group            TEXT NOT NULL,
  PRIMARY KEY (doc_packet_contract_id, doc_packet_signer_id)
);

CREATE TABLE doc_packet_doc_signer (
  doc_packet_doc_id       INTEGER NOT NULL REFERENCES doc_packet_doc(id) ON DELETE CASCADE,    
  doc_packet_signer_id    INTEGER NOT NULL REFERENCES doc_packet_signer(id) ON DELETE CASCADE,
  signer_group            TEXT NOT NULL,
  PRIMARY KEY (doc_packet_doc_id, signer_group)
);

CREATE TABLE doc_packet_log (
  id                    SERIAL PRIMARY KEY,
  doc_packet_id         INTEGER NOT NULL REFERENCES doc_packet(id) ON DELETE CASCADE,
  log_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  log_message           TEXT NOT NULL
);
-- END APP-948

-- APP-2832

CREATE TABLE obit_subscription (
  uuid                          UUID NOT NULL DEFAULT extensions.gen_random_uuid() PRIMARY KEY, -- used for opt-in and unsubscription urls
  website_id                    INTEGER NOT NULL references public.website(id),
  name                          TEXT NOT NULL,
  email                         TEXT NOT NULL,
  created_time                  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  opt_in_time                   TIMESTAMP WITH TIME ZONE,
  opt_in_ip                     TEXT,
  opt_out_time                  TIMESTAMP WITH TIME ZONE,
  opt_out_ip                    TEXT,
  last_failed_time              TIMESTAMP WITH TIME ZONE,
  last_failed_msg               TEXT,
  consecutive_failed_msg_count  INTEGER NOT NULL DEFAULT 0,
  total_success_msg_count       INTEGER NOT NULL DEFAULT 0,
  UNIQUE (website_id, email)
);

-- END APP-2832

-- APP-2807
CREATE TYPE public.notification_method_type AS ENUM (
  'sms',
  'email'
);

CREATE TYPE subscription_type AS ENUM (
  'memory: responses to me', 
 -- 'report: some report',
  'obit: by_website_id',
  'obit: by_newObject_id',
 'case: service summary', 
 'case: service reminder', 
 'case: new memories' 
);

CREATE TABLE entity_subscription (
  id                            SERIAL PRIMARY KEY,
  entity_id                     INTEGER NOT NULL REFERENCES entity(id),
  uuid                          UUID NOT NULL DEFAULT extensions.gen_random_uuid() UNIQUE,
  subscription_type             subscription_type NOT NULL, 
  notification_method           notification_method_type NOT NULL, -- e.g. "email", "sms" - probably an ENUM 
  opt_in_time                   TIMESTAMP WITH TIME ZONE,
  opt_in_ip                     TEXT,
  opt_out_time                  TIMESTAMP WITH TIME ZONE,
  opt_out_ip                    TEXT,
  last_failed_time              TIMESTAMP WITH TIME ZONE,
  last_failed_msg               TEXT,
  consecutive_failed_msg_count  INTEGER NOT NULL DEFAULT 0,
  created_time                  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW() ,
  created_by                    INTEGER,
  updated_time                  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW() ,
  updated_by                    INTEGER,
  deleted_time                  TIMESTAMP WITH TIME ZONE,
  deleted_by                    INTEGER,
    -- NOTE: add a new column when required by the subscription_type
  -- website_id                    INTEGER REFERENCES public.website(id), -- used for obit subscription
  -- memory_id                     INTEGER REFERENCES public.memory(id), -- used for responses to memory subscription
  gather_case_id                INTEGER REFERENCES public.gather_case(id) -- used for service  and new memory subscription
);

-- create a constraint to ensure that for a particular subscirption_type the gather_case_id is not null
ALTER TABLE entity_subscription ADD CONSTRAINT  ensure_subscription_target_not_null CHECK ( 
    (
    (subscription_type = 'case: service summary' OR subscription_type = 'case: service reminder' OR subscription_type = 'case: new memories') AND gather_case_id IS NOT NULL
    -- ) OR (
    -- (subscription_type = 'obit: by_website_id' OR subscription_type = 'obit: by_newObject_id') AND website_id IS NOT NULL
    -- ) OR (
    -- (subscription_type = 'memory: responses to me') AND memory_id IS NOT NULL
    )
);

CREATE INDEX entity_subscription_idx ON entity_subscription (subscription_type, notification_method, deleted_time);
CREATE UNIQUE INDEX entity_subscription_unique_idx ON entity_subscription (entity_id, subscription_type, notification_method, gather_case_id);

CREATE TYPE public.webhook_type AS ENUM (
    'twilio_sms',
    'twilio_clicktracking',
    'twilio_statuscallback',
    'hellosign_callback_general',
    'mux_callback_general',
    'stripe_webhook_general',
    'stripe_webhook_payment_intent',
    'google_webhook_general',
    'google_webhook_calendar',
    'duda_webhook_general'
);

CREATE TABLE public.webhook_log (
    id SERIAL PRIMARY KEY,
    created_time TIMESTAMP NOT NULL DEFAULT NOW(),
    webhook_type webhook_type NOT NULL, -- or this could be an ENUM/ DB TYPE
    data JSONB NOT NULL -- this would be flexible for the different webhook types
);
CREATE INDEX webhook_log_webhook_type_idx ON public.webhook_log(webhook_type);

-- END APP-2807

-- APP-916
CREATE TABLE product.supplier (
  id            SERIAL PRIMARY KEY, 
  name          TEXT NOT NULL 
);

CREATE TABLE product.supplier_photo (
  id                        SERIAL PRIMARY KEY,
  supplier_id               INTEGER NOT NULL REFERENCES product.supplier(id) ON DELETE CASCADE,
  photo_id                  INTEGER NOT NULL REFERENCES public.photo(id) ON DELETE CASCADE,
  youtube_data              TEXT
);

CREATE TABLE product.supplier_funeralhome (
  supplier_id               INTEGER NOT NULL REFERENCES product.supplier(id) ON DELETE CASCADE,
  funeral_home_id           INTEGER NOT NULL REFERENCES public.funeral_home(id) ON DELETE CASCADE,
  category                  product.category NOT NULL,
  fh_cloned_from            INTEGER REFERENCES funeral_home(id),
  fh_cloned_time            TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (supplier_id, funeral_home_id, category)
);
-- END APP-916

-- Creating an enum to record different types of products

CREATE TYPE public.sale_type AS ENUM ('flower', 'tree', 'book');

-- The following table holds a list of Arbor Day tree planing projects that we'll allow our users to donate to
-- The data in the table will be one or more States (where the project is located), the name of the project, a description of the project, the Arbor Day project ID, A hero image url, a square image URL, and the standard time stamps and user IDs
CREATE TABLE public.tree_project (
  id                        SERIAL PRIMARY KEY,
  rank                      INTEGER NOT NULL DEFAULT 0,
  start_date                TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  states                    TEXT NOT NULL, -- CSV delimited list of states
  name                      TEXT NOT NULL,
  subtitle                  TEXT NOT NULL,
  faq                       JSONB NOT NULL DEFAULT '[]'::JSONB, 
  description               TEXT NOT NULL,
  cost_per_tree             INTEGER NOT NULL DEFAULT 85,
  arbor_day_project_id      TEXT NOT NULL,
  hero_photo_view_id        INTEGER REFERENCES public.photo_view(id),
  detail_photo_view_id      INTEGER REFERENCES public.photo_view(id),
  created_by                INTEGER REFERENCES user_profile(id) NOT NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by                INTEGER REFERENCES user_profile(id) NOT NULL,
  updated_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by                INTEGER REFERENCES user_profile(id),
  deleted_time              TIMESTAMP WITH TIME ZONE,
  all_fh_can_access         BOOLEAN NOT NULL DEFAULT TRUE,
  featured_project          BOOLEAN NOT NULL DEFAULT FALSE
);

-- which funeral homes have access to tree_project. Ignored if tree_project.all_fh_can_access is set TRUE
CREATE TABLE public.funeral_home_with_tree_project_access (
  tree_project_id       INTEGER NOT NULL REFERENCES public.tree_project(id) ON DELETE CASCADE,
  funeral_home_id       INTEGER NOT NULL REFERENCES public.funeral_home(id) ON DELETE CASCADE,
  PRIMARY KEY (tree_project_id, funeral_home_id)
);

CREATE TABLE public.price_matrix_item (
  id                        SERIAL PRIMARY KEY,
  quantity                  INTEGER NOT NULL,
  name                      TEXT NOT NULL,
  price                     INTEGER NOT NULL,
  deleted_time              TIMESTAMP WITH TIME ZONE,
  type                      public.sale_type NOT NULL DEFAULT 'tree'
);

CREATE TYPE order_vendor AS ENUM ('arborday', 'floristone', 'teleflora', 'alexander');

-- END APP-1297
CREATE TABLE public.gather_product_order (
  id SERIAL PRIMARY KEY,
  created_by INTEGER REFERENCES user_profile(id),
  gather_payment_id INTEGER REFERENCES public.gather_payment(id),
  order_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  gather_case_id INTEGER NOT NULL REFERENCES gather_case(id),
  checkout_session_id TEXT UNIQUE, -- Payment provider checkout session ID
  checkout_session_customer_id TEXT, -- Payment provider customer ID
  order_number TEXT UNIQUE, -- Internal order number for reference
  customer_name TEXT NOT NULL DEFAULT'',
  customer_email TEXT NOT NULL DEFAULT'',
  customer_phone TEXT,
  customer_address_line_1 TEXT NOT NULL DEFAULT'',
  customer_address_line_2 TEXT,
  customer_city TEXT NOT NULL DEFAULT'',
  customer_state TEXT NOT NULL DEFAULT'',
  customer_zip TEXT NOT NULL DEFAULT'',
  notes TEXT
);

CREATE TYPE public.gather_product_order_email_status AS ENUM (
  'sent',
  'failed',
  'delivered'
);

CREATE TYPE public.gather_product_order_email_reason AS ENUM (
  'payment_receipt',
  'payment_failed',
  'order_cancelled_full',
  'order_cancelled_partial',
  'shipping'
);

CREATE TABLE public.gather_product_order_log (
  id SERIAL PRIMARY KEY,
  order_number TEXT REFERENCES public.gather_product_order(order_number) ON DELETE CASCADE,
  log_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  log_message TEXT NOT NULL,
  email_address TEXT,
  email_reason public.gather_product_order_email_reason,
  email_status public.gather_product_order_email_status
);

CREATE INDEX gather_product_order_log_order_number_idx ON public.gather_product_order_log(order_number);

CREATE TABLE public.gather_order_item (
  id                          SERIAL PRIMARY KEY,
  sale_type                   public.sale_type NOT NULL,
  show_message                BOOLEAN NOT NULL DEFAULT FALSE,
  product_thumbnail           TEXT,
  flower_high_res_image_url   TEXT,
  vendor_order_number         TEXT NOT NULL,
  order_request               JSONB NOT NULL DEFAULT '{}'::JSONB,
  order_response              JSONB NOT NULL DEFAULT '{}'::JSONB,
  quantity                    INTEGER NOT NULL DEFAULT 1,
  order_total                 INTEGER NOT NULL,
  tax_amount                  INTEGER,
  recipient                   JSONB,
  vendor                      order_vendor NOT NULL,
  vendor_product_code         TEXT NOT NULL,
  tree_project_id             INTEGER REFERENCES public.tree_project(id),
  commission_payed_time       TIMESTAMP WITH TIME ZONE,
  commission_payed_by         INTEGER REFERENCES user_profile(id),
  hidden_time                 TIMESTAMP WITH TIME ZONE,
  hidden_by                   INTEGER REFERENCES user_profile(id),
  gather_order_id             INTEGER NOT NULL REFERENCES gather_product_order (id) ON DELETE CASCADE
);

CREATE INDEX gather_order_case_id ON public.gather_product_order(gather_case_id);
CREATE INDEX gather_order_order_time ON public.gather_product_order(order_time);
CREATE INDEX gather_order_vendor_order_number_idx ON public.gather_order_item(vendor_order_number);

CREATE TABLE public.commission_payment (
  id                        SERIAL PRIMARY KEY,
  funeral_home_id           INTEGER NOT NULL REFERENCES public.funeral_home(id),
  amount                    INTEGER NOT NULL,
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by                INTEGER REFERENCES user_profile(id) NOT NULL,
  bill_number               TEXT NOT NULL,
  check_number              TEXT NOT NULL,
  reconciled_time           TIMESTAMP WITH TIME ZONE,
  reconciled_by             INTEGER REFERENCES user_profile(id),
  reconciled_note           TEXT
);

-- Workflows on cases
    -- can reorder tasks
    -- can complete tasks
    -- can delete tasks
    -- can add existing tasks w/ components
    -- AND can add NEW tasks w/o components (like a note)
    -- can NOT update tasks at case level
    -- tasks on case can be:
      -- When a case switches from one workflow to another: Completed tasks STAY
      -- tasks can't have content w/o being completed
      -- CANNOT modify content of completed tasks
  
-- Workflows
    -- "default_task_list" should become "workflow" and "tasks" and "tasks" will point to a workflow
    -- can be associated/shared between multiple FHs
    -- always specific to a case type
    -- Once used on a case can a workflow:
      -- be modified due to the original, underlying workflow being changed? NO!
      -- be changed for that case only? YES!

-- Workflow Funeral Home -- used by BACK OFFICE
CREATE TABLE public.funeral_home_workflow (
  funeral_home_id   INTEGER NOT NULL REFERENCES public.funeral_home(id),
  workflow_id       INTEGER NOT NULL REFERENCES public.workflow(id),
  rank              INTEGER NOT NULL,
  created_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by        INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time      TIMESTAMP WITH TIME ZONE,
  deleted_by        INTEGER REFERENCES public.user_profile(id),
  PRIMARY KEY (funeral_home_id, workflow_id)
);

-- Workflow Task -- used by BACK OFFICE only
-- Allows tasks to be shared between many workflows
CREATE TABLE public.workflow_task (
  id                  SERIAL PRIMARY KEY,
  task_id             INTEGER NOT NULL REFERENCES public.task(id),
  workflow_id         INTEGER NOT NULL REFERENCES public.workflow(id),
  rank                INTEGER NOT NULL,
  created_time        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by          INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time        TIMESTAMP WITH TIME ZONE,
  deleted_by          INTEGER REFERENCES public.user_profile(id)
);
CREATE INDEX workflow_task_workflow_id_idx ON public.workflow_task(workflow_id);
CREATE INDEX workflow_task_task_id_idx ON public.workflow_task(task_id);

-- Workflow Task Prerequisite -- used by BACK OFFICE only
-- NOTE: Has a sister table case_task_prerequisite
CREATE TABLE public.workflow_task_prerequisite (
  workflow_task_id          INTEGER NOT NULL REFERENCES public.workflow_task(id),
  prereq_workflow_task_id   INTEGER NOT NULL REFERENCES public.workflow_task(id),
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by                INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time              TIMESTAMP WITH TIME ZONE,
  deleted_by                INTEGER REFERENCES public.user_profile(id),
  PRIMARY KEY (workflow_task_id, prereq_workflow_task_id)
);

-- Case Task Prerequisite -- used by CASE only
-- NOTE: Has a sister table workflow_task_prerequisite
CREATE TABLE public.case_task_prerequisite (
  case_task_id              INTEGER NOT NULL REFERENCES public.case_task(task_id),
  prereq_case_task_id       INTEGER NOT NULL REFERENCES public.case_task(task_id),
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by                INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time              TIMESTAMP WITH TIME ZONE,
  deleted_by                INTEGER REFERENCES public.user_profile(id),
  PRIMARY KEY (case_task_id, prereq_case_task_id)
);

-- Need lots of logging because of legal liability
   -- types:
      -- workflow linked/unlinked to FH
      -- workflow updated
      -- task_component updated
      -- task updated
CREATE TYPE public.workflow_log_type AS ENUM ('task', 'task_component', 'workflow');
CREATE TABLE public.workflow_log (
  id                SERIAL PRIMARY KEY,
  workflow_id       INTEGER NOT NULL REFERENCES public.workflow(id),
  action_type       public.workflow_log_type NOT NULL,
  changes           TEXT NOT NULL, -- output from json-diff
  note              TEXT,
  action_time       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  action_by         INTEGER NOT NULL REFERENCES public.user_profile(id)
);

-- Case Label
-- labels must be unique to FH & changes made WILL affect cases using the label
CREATE TABLE public.case_label (
  id                      SERIAL PRIMARY KEY,
  name                    TEXT NOT NULL,
  color                   TEXT NOT NULL,
  funeral_home_id         INTEGER NOT NULL REFERENCES public.funeral_home(id),
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time            TIMESTAMP WITH TIME ZONE,
  deleted_by              INTEGER REFERENCES public.user_profile(id),
  UNIQUE(funeral_home_id, name)
);
CREATE INDEX case_label_funeral_home_id_idx ON public.case_label(funeral_home_id);

-- Case Label Case
-- associates case labels with a case
CREATE TABLE public.case_label_case (
  case_label_id             INTEGER NOT NULL REFERENCES public.case_label(id),
  gather_case_id            INTEGER NOT NULL REFERENCES public.gather_case(id),
  created_time              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by                INTEGER NOT NULL REFERENCES public.user_profile(id),
  deleted_time              TIMESTAMP WITH TIME ZONE,
  deleted_by                INTEGER REFERENCES public.user_profile(id),
  PRIMARY KEY (case_label_id, gather_case_id)
);

CREATE INDEX case_label_case_gather_case_id_idx ON public.case_label_case(gather_case_id);

-- Update the denormalized gather_case.case_label_ids when a case_label_case is added, updated, or removed
CREATE OR REPLACE FUNCTION trigger_set_case_label_ids()
RETURNS TRIGGER AS $$
DECLARE
    _gather_case_id INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        _gather_case_id := OLD.gather_case_id;
    ELSE
        _gather_case_id := NEW.gather_case_id;
    END IF;

    UPDATE gather_case
    SET case_label_ids = ARRAY(
        SELECT clc.case_label_id
        FROM case_label_case AS clc
        WHERE clc.gather_case_id = _gather_case_id
            AND clc.deleted_time IS NULL
    )
    WHERE id = _gather_case_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_case_label_ids_trig
AFTER INSERT OR UPDATE OR DELETE ON public.case_label_case
FOR EACH ROW
EXECUTE FUNCTION trigger_set_case_label_ids();

CREATE TYPE public.case_belonging_decision_type AS ENUM ('return_to_family', 'keep', 'donate', 'dispose', 'unsure');

-- Case Belonging
CREATE TABLE public.case_belonging (
  id                                SERIAL PRIMARY KEY,
  gather_case_id                    INTEGER NOT NULL REFERENCES public.gather_case(id),
  photo_s3_file_id                  INTEGER REFERENCES public.s3_file(id),
  name                              TEXT NOT NULL,
  description                       TEXT,
  decision                          public.case_belonging_decision_type NOT NULL,
  decision_signature_s3_file_id     INTEGER NOT NULL REFERENCES public.s3_file(id),
  created_time                      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by                        INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time                      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by                        INTEGER NOT NULL REFERENCES public.user_profile(id),
  completed_time                    TIMESTAMP WITH TIME ZONE,
  completed_by                      INTEGER REFERENCES public.user_profile(id),
  completed_by_signature_s3_file_id INTEGER REFERENCES public.s3_file(id),
  deleted_time                      TIMESTAMP WITH TIME ZONE,
  deleted_by                        INTEGER REFERENCES public.user_profile(id)
);
CREATE INDEX case_belonging_gather_case_id_idx ON public.case_belonging(gather_case_id);

CREATE FUNCTION is_date(s VARCHAR) RETURNS BOOLEAN AS $$
BEGIN
  PERFORM s::DATE;
  RETURN TRUE;
EXCEPTION WHEN others THEN
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION fail_if(_condition BOOLEAN, _msg TEXT) RETURNS BOOLEAN
AS $$
BEGIN
  ASSERT NOT _condition, _msg;
  RETURN TRUE;
END;
$$
LANGUAGE plpgsql;

-- APP-2286 - Tracking Tags 

CREATE TYPE keeptrack_tag_type AS ENUM ('tracking', 'keepsake');
CREATE TYPE keeptrack_card_type AS ENUM ('keeptrack', 'additional');

CREATE TABLE public.keeptrack_tag_batch (
  id                    SERIAL PRIMARY KEY,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE public.keeptrack_tag (
  id                       TEXT PRIMARY KEY,
  created_time             TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL, -- generated QR
  batch_id                 INTEGER REFERENCES keeptrack_tag_batch(id),
  tag_type                 keeptrack_tag_type NOT NULL,
  is_physical              BOOLEAN NOT NULL,
  reserved_time            TIMESTAMP WITH TIME ZONE, -- added to a batch
  received_time            TIMESTAMP WITH TIME ZONE, -- verified QR etched
  allocated_time           TIMESTAMP WITH TIME ZONE, -- assigned to FH (unused / TBD)
  deleted_time             TIMESTAMP WITH TIME ZONE,
  CONSTRAINT valid_keepsake CHECK (tag_type = 'tracking' OR LEFT(id, 1) = 'K'),
  CONSTRAINT valid_tracker CHECK (tag_type = 'keepsake' OR LEFT(id, 1) = 'T')
);

CREATE TABLE public.keeptrack_card (
  keepsake_id              TEXT PRIMARY KEY REFERENCES keeptrack_tag(id),
  tracker_id               TEXT REFERENCES keeptrack_tag(id) UNIQUE,
  card_type                keeptrack_card_type NOT NULL,
  gather_case_id           INTEGER REFERENCES gather_case(id),
  scanned_time             TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL, -- tracker and keepsake linked, creation time for additional tags
  assigned_time            TIMESTAMP WITH TIME ZONE, -- added to a case
  finalized_time           TIMESTAMP WITH TIME ZONE, -- KeepTrack flow finalized on case
  deleted_time             TIMESTAMP WITH TIME ZONE,
  CONSTRAINT valid_keepsake CHECK (LEFT(keepsake_id, 1) = 'K'),
  CONSTRAINT valid_tracker CHECK (tracker_id IS NULL OR LEFT(tracker_id, 1) = 'T'),
  CONSTRAINT assigned_time_and_case_match CHECK ((assigned_time IS NULL) = (gather_case_id IS NULL)), -- XNOR
  CONSTRAINT need_case_to_finalize CHECK (finalized_time IS NULL OR gather_case_id IS NOT NULL),
  CONSTRAINT different_tags CHECK (keepsake_id != tracker_id),
  CONSTRAINT valid_keeptrack CHECK (card_type = 'additional' OR tracker_id IS NOT NULL),
  CONSTRAINT valid_additional CHECK (card_type = 'keeptrack' OR tracker_id IS NULL),
  UNIQUE (gather_case_id, tracker_id)
);
CREATE UNIQUE INDEX one_keeptrack_card_type_per_case_idx ON public.keeptrack_card (gather_case_id) WHERE card_type = 'keeptrack';
CREATE INDEX keeptrack_card_filter_idx
  ON public.keeptrack_card (gather_case_id, deleted_time, assigned_time, finalized_time, card_type)
  WHERE deleted_time IS NULL
    AND assigned_time IS NOT NULL
    AND finalized_time IS NULL
    AND card_type = 'keeptrack'
;

-- A table to keep track of which cases are part of marketing tests, which case, which test, and witch group
CREATE TABLE public.marketing_test (
  id                    SERIAL PRIMARY KEY,
  gather_case_id        INTEGER NOT NULL REFERENCES public.gather_case(id),
  test_name             TEXT NOT NULL,
  test_group            TEXT NOT NULL,
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
-- An index to make looking up marketing_tests by gather_case_id faster
CREATE INDEX marketing_test_gather_case_id_idx ON public.marketing_test(gather_case_id);

-- enum of the available report data sources
CREATE TYPE report_data_source_type AS ENUM (
  'case_non_financial',
  'case_financial',
  'case_vitals',
  'invoice_line_items',
  'events',
  'helpers',
  'notes',
  'task_and_step_activity',
  'payments',
  'remember_page',
  'insurance_policies'
);

CREATE TYPE report_date_range_type AS ENUM (
  'today',
  'yesterday',
  'last_7_days',
  'last_14_days',
  'last_28_days',
  'last_30_days',
  'last_60_days',
  'last_90_days',
  'current_week',
  'prev_week',
  'current_month',
  'prev_month',
  'current_quarter',
  'prev_quarter',
  'current_year',
  'prev_year',
  'custom'
);
-- A table that stores report configurations
-- The MUI DataGridPro info will be stored in a JSONB column
CREATE TABLE public.report (
  id                    SERIAL PRIMARY KEY,
  uuid                  UUID NOT NULL DEFAULT extensions.gen_random_uuid() UNIQUE,
  name                  TEXT NOT NULL,
  description           TEXT,
  is_gather_report      BOOLEAN NOT NULL DEFAULT FALSE,
  date_type             TEXT NOT NULL,
  date_range            report_date_range_type NOT NULL,
  -- date_range == 'custom' will use `custom_from_date` and `custom_to_date`, otherwise these fields are ignored
  custom_from_date      TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  custom_to_date        TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  data_source           report_data_source_type NOT NULL,
  created_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by            INTEGER REFERENCES public.user_profile(id) DEFAULT NULL,
  deleted_time          TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  -- owned_by is used for all report permissions. schedules have a related owned_by field as well
  owned_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  mui_config            JSONB,
  is_featured_default   BOOLEAN NOT NULL DEFAULT FALSE,
  all_fh_can_access     BOOLEAN NOT NULL
);

-- which funeral homes have access to report. Ignored if report.all_fh_can_access is set TRUE
CREATE TABLE public.funeral_home_with_report_access (
  report_id             INTEGER NOT NULL REFERENCES public.report(id) ON DELETE CASCADE,
  funeral_home_id       INTEGER NOT NULL REFERENCES public.funeral_home(id) ON DELETE CASCADE,
  PRIMARY KEY (report_id, funeral_home_id)
);

CREATE TABLE public.user_with_report_access (
  report_id             INTEGER NOT NULL REFERENCES public.report(id) ON DELETE CASCADE,
  user_profile_id       INTEGER NOT NULL REFERENCES public.user_profile(id) ON DELETE CASCADE,
  PRIMARY KEY (report_id, user_profile_id)
);

-- schedule reports using a cron expression
CREATE TABLE public.report_schedule (
  id                    SERIAL PRIMARY KEY,
  -- uuid will be schedule name, from the docs, the name has to be unique ^[0-9a-zA-Z-_.]+$
  uuid                  UUID NOT NULL DEFAULT extensions.gen_random_uuid() UNIQUE,
  -- The AWS EventBridge Schedule name is used for looking it up, updating it, and deleting it
  -- Don't cascade deletes because we need to clean up the AWS EventBridge Schedule first
  description           TEXT NOT NULL,
  report_id             INTEGER NOT NULL REFERENCES public.report(id),
  cron                  TEXT NOT NULL,
  ui_schedule_for_cron  JSONB, -- should only be NULL for CURSED reports. Make NOT NULL after CURSED reports are obliterated
  static_query          TEXT,
  additional_emails     TEXT NOT NULL DEFAULT '',
  -- timezone is used both for AWS schedule and for the report data
  timezone              TEXT NOT NULL DEFAULT 'America/Denver',
  -- date type/range fields get copied from the report but can be changed on a schedule-by-schedule basis
  date_type             TEXT NOT NULL,
  date_range            report_date_range_type NOT NULL,
  -- date_range == 'custom' will use `custom_from_date` and `custom_to_date`, otherwise these fields are ignored
  custom_from_date      TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  custom_to_date        TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  arn                   TEXT,
  created_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  updated_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  deleted_by            INTEGER REFERENCES public.user_profile(id),
  deleted_time          TIMESTAMP WITH TIME ZONE,
  owned_by              INTEGER NOT NULL REFERENCES public.user_profile(id),
  is_enabled            BOOLEAN NOT NULL DEFAULT TRUE,
  send_if_empty         BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE public.report_schedule_recipient (
  report_schedule_id    INTEGER NOT NULL REFERENCES public.report_schedule(id) ON DELETE CASCADE,
  user_profile_id       INTEGER NOT NULL REFERENCES public.user_profile(id) ON DELETE CASCADE,
  PRIMARY KEY (report_schedule_id, user_profile_id)
);

-- Which funeral homes were selected as part of a report schedule
CREATE TABLE public.report_schedule_funeral_home (
  report_schedule_id    INTEGER NOT NULL REFERENCES public.report_schedule(id) ON DELETE CASCADE,
  funeral_home_id       INTEGER NOT NULL REFERENCES public.funeral_home(id) ON DELETE CASCADE,
  PRIMARY KEY (report_schedule_id, funeral_home_id)
);

-- Keep track of the status of the report generation
CREATE TYPE report_status_type AS ENUM ('pending', 'running', 'success', 'failed', 'stale');
CREATE TYPE report_launch_type AS ENUM ('manual', 'scheduled', 'scheduled_now');

-- A table that stores the report generation status
CREATE TABLE public.report_execution (
  id                    SERIAL PRIMARY KEY,
  report_id             INTEGER NOT NULL REFERENCES public.report(id),
  launch_type           report_launch_type NOT NULL,
  status                report_status_type NOT NULL DEFAULT 'pending',
  report_schedule_id    INTEGER REFERENCES public.report_schedule(id) ON DELETE SET NULL,
  cron                  TEXT, -- schedule cron expression at time of execution
  created_by            INTEGER NOT NULL REFERENCES public.user_profile(id),
  created_time          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  error                 TEXT,
  file_size             INTEGER,
  run_start_time        TIMESTAMP WITH TIME ZONE,
  run_end_time          TIMESTAMP WITH TIME ZONE,
  run_duration_msec     FLOAT
);
-- Add an index to make looking up report_execution by report_schedule_id faster
CREATE INDEX report_execution_report_schedule_id_idx ON public.report_execution(report_schedule_id);

CREATE TYPE insurance_sync_status_type AS ENUM ('running', 'success', 'failed', 'stale');

-- Insurance company
CREATE TABLE public.insurance_carrier (
    id                              SERIAL PRIMARY KEY,
    key                             TEXT NOT NULL UNIQUE,
    name                            TEXT NOT NULL,
    sync_enabled                    BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by                      INTEGER REFERENCES public.user_profile(id),
    updated_time                    TIMESTAMP WITH TIME ZONE,
    created_time                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_by                      INTEGER REFERENCES public.user_profile(id),
    deleted_time                    TIMESTAMP WITH TIME ZONE
);

-- Type to track source of sync (e.g. manual run vs. scheduled batch job)
CREATE TYPE insurance_sync_type AS ENUM ('manual', 'automated');
CREATE TYPE insurance_sync_log_type AS ENUM ('changed', 'issued', 'historical');

-- Table to store the sync logs
CREATE TABLE public.insurance_sync_log (
    id                              SERIAL PRIMARY KEY,
    insurance_carrier_id            INTEGER NOT NULL REFERENCES public.insurance_carrier(id),
    sync_status                     insurance_sync_status_type NOT NULL,
    sync_start_time                 TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sync_end_time                   TIMESTAMP WITH TIME ZONE,
    sync_error                      TEXT,
    created_time                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_last_updated_time          TIMESTAMP WITH TIME ZONE,
    sync_type                       insurance_sync_type NOT NULL,
    sync_log_type                   insurance_sync_log_type NOT NULL
);

-- Policy
CREATE TABLE public.insurance_policy (
    id                              SERIAL PRIMARY KEY,
    policy_number                   VARCHAR(255) NOT NULL,
    issue_date                      DATE NOT NULL,
    policy_data                     JSONB NOT NULL,
    removed_from_dashboard_time     TIMESTAMP WITH TIME ZONE,
    attached_time                   TIMESTAMP WITH TIME ZONE,
    attached_by                     INTEGER REFERENCES public.user_profile(id),
    insurance_carrier_id            INTEGER NOT NULL REFERENCES public.insurance_carrier(id),
    funeral_home_id                 INTEGER REFERENCES public.funeral_home(id),
    funeral_home_case_id            INTEGER REFERENCES public.funeral_home_case(id),
    created_time                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by                      INTEGER REFERENCES public.user_profile(id),
    updated_time                    TIMESTAMP WITH TIME ZONE,
    deleted_by                      INTEGER REFERENCES public.user_profile(id),
    deleted_time                    TIMESTAMP WITH TIME ZONE,
    error_message                   TEXT,

    CONSTRAINT insurance_unique_policy_key UNIQUE (policy_number, insurance_carrier_id)
);

CREATE INDEX insurance_policy_issue_date_idx ON public.insurance_policy(issue_date);
CREATE INDEX insurance_policy_funeral_home_id_idx ON public.insurance_policy(funeral_home_id);

-- APP-3780

CREATE TYPE test_type AS ENUM ('tree_seed');

CREATE TABLE public.case_test (
    id                              SERIAL PRIMARY KEY,
    gather_case_id                  INTEGER REFERENCES gather_case(id),
    created_date                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    test_type                       test_type NOT NULL,
    test_group                      CHAR NOT NULL
);

CREATE UNIQUE INDEX unique_gather_case_id_test_type ON public.case_test (gather_case_id, test_type);

-- APP-3211 books
CREATE SCHEMA book;

CREATE TYPE book.cover_template_type AS ENUM ('singleWithMargins', 'singleFullBleed', 'sixUpMixed', 'twoUpPortrait');

CREATE TABLE book.book (
  id                     SERIAL PRIMARY KEY,
  uuid                   UUID UNIQUE DEFAULT extensions.gen_random_uuid(),
  created_time           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by             INTEGER REFERENCES public.user_profile(id) NOT NULL,
  updated_time           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by             INTEGER REFERENCES public.user_profile(id) NOT NULL,
  deleted_time           TIMESTAMP WITH TIME ZONE,
  deleted_by             INTEGER REFERENCES public.user_profile(id),
  gather_case_id         INTEGER NOT NULL REFERENCES public.gather_case(id),
  theme_id               INTEGER REFERENCES public.theme(id),
  book_s3_file_id        INTEGER REFERENCES public.s3_file(id),
  cover_s3_file_id       INTEGER REFERENCES public.s3_file(id),
  cover_template_type    book.cover_template_type NOT NULL,
  cover_spine_width_mm   INTEGER NOT NULL,
  cover_height_in        DECIMAL(6,4) NOT NULL,
  cover_width_in         DECIMAL(6,4) NOT NULL
);

CREATE TYPE book.background AS ENUM ('white', 'themePrimaryColor', 'themeSecondaryColor', 'themePrimaryBackground', 'themeSecondaryBackground');
CREATE TYPE book.page_type AS ENUM ('photo', 'memory', 'obit', 'guestList');
CREATE TYPE book.photo_template AS ENUM ('title', 'singleFullBleed', 'singleWithMargins', 'twoUpLandscape', 'twoUpPortrait', 'threeUpPortrait', 'threeUpLandscape', 'fourUp', 'sixUpLandscape', 'sixUpPortrait', 'leftOversLandscape', 'leftOversPortrait', 'leftOversSquare');
CREATE TYPE book.memory_template AS ENUM ('singleMemory', 'doubleMemory', 'candleMemory', 'flowerMemory', 'treeMemory', 'multiPageMemory');
CREATE TYPE book.obit_template AS ENUM ('obitTitle', 'obitPage');

ALTER TABLE public.deep_link ADD COLUMN
  book_uuid       UUID REFERENCES book.book(uuid) ON DELETE CASCADE;
CREATE INDEX deep_link_book_uuid_index ON public.deep_link(book_uuid);

CREATE TABLE book.page (
  id                     SERIAL PRIMARY KEY,
  book_id                INTEGER NOT NULL REFERENCES book.book(id),
  page_number            INTEGER NOT NULL,
  background             book.background NOT NULL,
  page_data              JSONB,
  type                   book.page_type NOT NULL,
  photo_template         book.photo_template,
  memory_template        book.memory_template,
  obit_template          book.obit_template,
  CONSTRAINT check_page_template CHECK (
    (type = 'photo' AND photo_template IS NOT NULL) OR
    (type = 'memory' AND memory_template IS NOT NULL) OR
    (type = 'obit' AND obit_template IS NOT NULL) OR
    type = 'guestList'
  )
);

CREATE TABLE book.page_photo (
  page_id                INTEGER NOT NULL REFERENCES book.page(id),
  photo_view_id          INTEGER NOT NULL REFERENCES public.photo_view(id),
  width_in               DECIMAL(6,4) NOT NULL, -- width in inches, e.g. 11.0044
  height_in              DECIMAL(6,4) NOT NULL, -- height in inches, e.g. 04.0010
  rank                   INTEGER NOT NULL,
  PRIMARY KEY(page_id, photo_view_id)
);

CREATE TABLE book.page_memory (
  id                     SERIAL PRIMARY KEY,
  page_id                INTEGER NOT NULL REFERENCES book.page(id),
  author_name            TEXT NOT NULL,
  author_relation        TEXT,
  message                TEXT NOT NULL,
  question               TEXT,
  flower_photo_url       TEXT,
  tree_project_id        INTEGER REFERENCES public.tree_project(id),
  rank                   INTEGER NOT NULL,
  multi_page_data        JSONB
);

CREATE TABLE book.page_guest_list_guest (
  id                     SERIAL PRIMARY KEY,
  column_number          INTEGER NOT NULL,
  page_id                INTEGER NOT NULL REFERENCES book.page(id),
  name                   TEXT NOT NULL,
  entity_id              INTEGER NOT NULL REFERENCES public.entity(id),
  relationship           TEXT,
  photo_view_id          INTEGER REFERENCES public.photo_view(id),
  rank                   INTEGER NOT NULL
);

CREATE TABLE book.front_cover_photo (
  book_id                INTEGER NOT NULL REFERENCES book.book(id),
  photo_view_id          INTEGER NOT NULL REFERENCES public.photo_view(id),
  rank                   INTEGER NOT NULL,
  PRIMARY KEY(book_id, photo_view_id)
);

CREATE TYPE book.print_order_status AS ENUM (
  'created', 'pending', 'invoiced', 'printing', 'shipped', 'canceling',
  'canceled', 'canceled_invoiced', 'error'
);

CREATE TABLE book.print_order (
  uuid                   UUID PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  vendor_order_id        TEXT,
  created_time           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_by             INTEGER REFERENCES public.user_profile(id) NOT NULL,
  updated_time           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_by             INTEGER REFERENCES public.user_profile(id) NOT NULL,
  book_id                INTEGER NOT NULL REFERENCES book.book(id),
  order_log              JSONB NOT NULL DEFAULT '[]',
  customer_id            INTEGER REFERENCES public.entity(id),
  order_details          JSONB, -- vendor specific order details
  due_date               TIMESTAMP WITH TIME ZONE,
  status                 book.print_order_status NOT NULL DEFAULT 'pending'::book.print_order_status,
  gather_case_id         INTEGER NOT NULL REFERENCES public.gather_case(id)
);


-- APP-1361 dataload

-- Create a sandbox schema where all the dataload tables and functions will live
CREATE SCHEMA dataload;
-- The dataloader role will not have a login, but will be the ROLE for all dataloader users
CREATE ROLE dataloader;
-- Don't let data loader people have direct access to the public schema
REVOKE USAGE ON SCHEMA public FROM dataloader;
GRANT USAGE ON SCHEMA dataload TO dataloader;
-- dataloader can select data from any view in this schema and run any function
ALTER DEFAULT PRIVILEGES IN SCHEMA dataload GRANT SELECT ON TABLES TO dataloader;
ALTER DEFAULT PRIVILEGES IN SCHEMA dataload GRANT EXECUTE ON FUNCTIONS TO dataloader;

-- Set up a user that can log in and interact with the dataload schema
CREATE ROLE datauser WITH LOGIN INHERIT PASSWORD 'd@t@GURU:")';
ALTER ROLE datauser SET search_path = dataload;
GRANT dataloader to datauser;

-- Limited view of funeral_home for the dataload schema
CREATE VIEW dataload.dl_funeral_home AS
SELECT fh.id, fh.key, fh.name, fh.is_demo, fh.is_test, fh.deleted_time, rev.id AS dc_config_rev_id-- force imported cases to FH's default imported case config
FROM public.funeral_home AS fh
JOIN death_certificate_config as dc_config
  ON dc_config.funeral_home_id = fh.id
JOIN death_certificate_config_revision AS rev
  ON rev.config_id = dc_config.id
WHERE dc_config.imported_case_config
  AND rev.imported_case_config
;

-- Limited view of the user_profile for the dataload schema
CREATE VIEW dataload.dl_user_profile AS
SELECT up.id, ufh.funeral_home_id, e.fname, e.lname, up.email, up.deleted_time, ufh.deactivated_time IS NULL AS is_active
FROM public.user_funeral_home ufh
JOIN public.user_profile up ON up.id = ufh.user_profile_id
JOIN public.entity e ON e.id = up.entity_id
;

-- Limited view of the gather_case for the dataload schema
CREATE FUNCTION dataload.find_gather_case (_funeral_home_id INTEGER, _case_number TEXT, _all_cases BOOLEAN DEFAULT FALSE)
    RETURNS TEXT AS $find_gather_case$
DECLARE
  gather_case_uuid TEXT;
BEGIN
  SELECT INTO gather_case_uuid
  fh_case.uuid FROM public.gather_case AS gc
  JOIN public.funeral_home_case AS fh_case
    ON fh_case.gather_case_id = gc.id
  WHERE fh_case.funeral_home_id = _funeral_home_id
    AND fh_case.case_number = _case_number
    AND fh_case.deleted_time IS NULL
    AND gc.deleted_time IS NULL
    AND (gc.imported_time IS NOT NULL OR _all_cases = TRUE)
  ORDER BY gc.id DESC
  LIMIT 1
  ;
  RETURN gather_case_uuid;
END;
$find_gather_case$
LANGUAGE plpgsql SECURITY DEFINER;

-- A list of all the available entity relationship types
CREATE VIEW dataload.dl_entity_relationship AS
SELECT UNNEST(ENUM_RANGE(NULL::public.entity_relationship)) AS relationship
;

CREATE TYPE dataload.batch_type AS ENUM ('case', 'entity', 'casefile', 'rolodex', 'obit', 'event', 'insurance');
CREATE TYPE dataload.batch_status AS ENUM ('staging', 'staged', 'valid', 'invalid', 'committed', 'failed');

CREATE TABLE dataload.batch (
  id               SERIAL PRIMARY KEY,
  batch_type       dataload.batch_type NOT NULL,
  batch_status     dataload.batch_status NOT NULL DEFAULT 'staging'::dataload.batch_status,
  funeral_home_id  INTEGER NOT NULL REFERENCES funeral_home(id),
  processed_by     text,
  created_time     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_time     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE dataload.datarow (
  id            SERIAL PRIMARY KEY,
  batch_id      INTEGER NOT NULL REFERENCES dataload.batch(id),
  row_number    INTEGER NOT NULL,
  status        dataload.batch_status NOT NULL DEFAULT 'staging'::dataload.batch_status,
  data          JSONB NOT NULL
);

CREATE FUNCTION dataload.create_batch (
  _batch_type dataload.batch_type,
  _funeral_home_id INTEGER,
  _data TEXT,
  _batch_id INTEGER)
    RETURNS INTEGER AS $create_batch$
DECLARE
  batch_id INTEGER;
  current_row_number INTEGER;
BEGIN
  IF _batch_id IS NULL THEN

    INSERT INTO dataload.batch (batch_type, funeral_home_id, processed_by)
    VALUES (_batch_type, _funeral_home_id, session_user) RETURNING id INTO batch_id;
    
    -- Initialize the row number
    current_row_number := 0;
    
  ELSE -- We're adding to an existing batch
    SELECT COALESCE(NULLIF(COUNT(*), 0), 0) INTO current_row_number
    FROM dataload.datarow
    WHERE dataload.datarow.batch_id = _batch_id;

    batch_id := _batch_id;
  END IF;
  
  INSERT INTO dataload.datarow (batch_id, row_number, data)
  SELECT
    batch_id,
    current_row_number + ROW_NUMBER() OVER () AS row_number,
    stagedata.data
  FROM (SELECT JSONB_ARRAY_ELEMENTS(_data::JSONB) AS data) AS stagedata;

  RETURN batch_id;
END;
$create_batch$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION dataload.add_case_task(_gather_case_id INTEGER, _funeral_home_case_id INTEGER, _workflow_id INTEGER, _funeral_home_id INTEGER)
  RETURNS INTEGER AS $added_case_task_id$
DECLARE
    _existing_task_id INTEGER;
    _new_task_id INTEGER;
BEGIN
  SELECT INTO _existing_task_id
    ct.task_id
  FROM public.case_task AS ct
  JOIN public.task AS t
    ON t.id = ct.task_id
  WHERE ct.funeral_home_case_id = _funeral_home_case_id
    AND t.deleted_time IS NULL
    AND t.template_type = 'death_certificate'
    AND t.type = 'checklist_task';

  IF _existing_task_id IS NOT NULL THEN
    -- If the task already exists, just return the existing task id
    RETURN _existing_task_id;
  ELSE
    WITH task_template AS (
      SELECT
          fht.funeral_home_id,
          MAX(t.id) AS task_template_id
      FROM public.funeral_home_task AS fht
      JOIN public.task AS t
        ON t.id = fht.task_id
      WHERE t.template_type = 'death_certificate'
        AND t.type = 'checklist_task'
        AND t.deleted_time IS NULL
        AND fht.funeral_home_id = _funeral_home_id
      GROUP BY fht.funeral_home_id
    ),
    new_task AS (
      INSERT INTO public.task (
          type,
          icon,
          title,
          past_tense_title,
          subtitle,
          description,
          template_type,
          tracking_step_type,
          can_complete,
          can_skip,
          visible_to_family,
          can_reassign_by_family,
          can_assign_multiple,
          is_after_care,
          created_by,
          updated_by,
          from_task_id
      )
      SELECT 
          t.type,
          t.icon,
          t.title,
          t.past_tense_title,
          t.subtitle,
          t.description,
          t.template_type,
          t.tracking_step_type,
          t.can_complete,
          t.can_skip,
          t.visible_to_family,
          t.can_reassign_by_family,
          t.can_assign_multiple,
          t.is_after_care,
          0 AS created_by,
          0 AS updated_by,
          t.id AS from_task_id
      FROM task_template AS tt
      JOIN public.task AS t
          ON t.id = tt.task_template_id
      RETURNING id
    )
    SELECT id INTO _new_task_id FROM new_task;

    INSERT INTO public.case_task (
        task_id,
        rank,
        funeral_home_case_id,
        marked_complete_by,
        marked_complete_time
    )
    VALUES (
        _new_task_id,
        1,
        _funeral_home_case_id,
        0,
        NOW()
    );
    RETURN _new_task_id;
  END IF;
END;
$added_case_task_id$
LANGUAGE plpgsql SECURITY DEFINER;


CREATE FUNCTION dataload.process_case_row (_batch_id INTEGER, _row_number INTEGER, _all_cases BOOLEAN DEFAULT FALSE)
  RETURNS JSONB AS $process_row$
DECLARE
  _datarow dataload.datarow;
  _funeral_home_id INTEGER;
  _gather_case_id INTEGER;
  _is_case_imported BOOLEAN;
  _note_id INTEGER;
  _dc_config_rev_id INTEGER;
  _workflow_id INTEGER;
  _funeral_home_case_id INTEGER;
BEGIN
  SELECT INTO _datarow * FROM dataload.datarow WHERE batch_id = _batch_id AND row_number = _row_number LIMIT 1;
  IF _datarow.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Unable to find data row for batch_id=%s, row_number=%s', _batch_id, _row_number),
      'gather_case_id', NULL);
  ELSIF _datarow.status != 'staging'::dataload.batch_status THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Row status is not ''staging'' but already ''%s''', _datarow.status),
      'gather_case_id', NULL);
  ELSE
    SELECT INTO _funeral_home_id
      funeral_home_id
    FROM dataload.batch
    WHERE id = _batch_id
    LIMIT 1;
    -- See if this case already exists, and store the id if it does
    SELECT INTO _gather_case_id, _is_case_imported, _dc_config_rev_id, _workflow_id, _funeral_home_case_id
      gc.id, gc.imported_time IS NOT NULL, gc.dc_config_rev_id, fh_case.workflow_id, fh_case.id
    FROM public.gather_case AS gc
    JOIN public.funeral_home_case AS fh_case
      ON fh_case.gather_case_id = gc.id
    JOIN dataload.batch AS b ON b.id = _datarow.batch_id
    WHERE fh_case.funeral_home_id = b.funeral_home_id
      AND fh_case.case_number = _datarow.data->>'case_number' -- case number has to match
      AND fh_case.deleted_time IS NULL -- ignore deleted cases
      AND gc.deleted_time IS NULL -- ignore deleted cases
    ORDER BY gc.id DESC
    LIMIT 1; -- only get one (we need to add a unique index on fh_id, case_number)

    IF (_all_cases = FALSE) AND NOT _is_case_imported THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'message', FORMAT('ERROR: case number ''%s'' is not imported and does not allow update via import', _datarow.data->>'case_number'),
        'gather_case_id', _gather_case_id);
    END IF;
    IF _workflow_id IS NULL THEN -- This case doesn't have a workflow, so we'll assign the default workflow for its case type
      SELECT INTO _workflow_id
        workflow.id
      FROM public.workflow
      JOIN public.funeral_home_workflow
        ON funeral_home_workflow.workflow_id = workflow.id
      JOIN public.funeral_home
        ON funeral_home.id = funeral_home_workflow.funeral_home_id
      JOIN dataload.batch
        ON funeral_home.id = batch.funeral_home_id
      WHERE workflow.case_type = (_datarow.data->>'case_type')::public.case_type
      AND workflow.imported_case = TRUE
      ORDER BY workflow.id DESC
      LIMIT 1;

    END IF;

    IF _gather_case_id IS NULL THEN -- This case doesn't already exist, so insert it now
      WITH createdCase AS (
        INSERT INTO public.gather_case (
          funeral_home_id,
          created_time, updated_time, fname, mname, lname, suffix, dob_date,
          dod_start_date, dod_start_time, dod_start_tz,
          imported_time, created_by, updated_by,
          death_certificate, dc_config_rev_id, death_certificate_locked)
        SELECT
          fh.id,
          (_datarow.data->>'created_time')::TIMESTAMP,
          (_datarow.data->>'created_time')::TIMESTAMP,
          _datarow.data->>'fname',
          _datarow.data->>'mname',
          _datarow.data->>'lname',
          _datarow.data->>'suffix',
          NULLIF(_datarow.data->>'date_of_birth', ''),
          NULLIF(_datarow.data->>'date_of_death', ''),
          _datarow.data->>'time_of_death',
          COALESCE(ad.timezone, 'America/Denver'),
          NOW(), -- imported_time
          assignee.id, assignee.id, -- created_by, updated_by
          _datarow.data->'dc',
          COALESCE(_dc_config_rev_id, (_datarow.data->>'dc_config_rev_id')::INTEGER), -- force imported cases to default imported case config for the FH
          TRUE -- death_certificate_locked
        FROM dataload.batch AS b
        JOIN public.funeral_home fh ON fh.id = b.funeral_home_id
        JOIN public.address ad ON ad.id = fh.address_id
        JOIN public.user_profile AS assignee ON assignee.email = _datarow.data->>'assignee.email'
        WHERE b.id = _batch_id
        RETURNING *
      )
      -- insert funeral_home_case for created case
      INSERT INTO public.funeral_home_case (funeral_home_id, gather_case_id, case_number, assignee_id, case_type, archived_time, created_by, updated_by, case_type_change_by, created_time, updated_time, case_type_change_time, workflow_id)
      SELECT
        funeral_home_id,
        createdCase.id AS gather_case_id,
        _datarow.data->>'case_number' AS case_number,
        assignee.id AS assignee_id,
        (_datarow.data->>'case_type')::public.case_type,
        NOW(), -- archived_time
        createdCase.created_by,
        createdCase.updated_by,
        createdCase.created_by AS case_type_change_by,
        createdCase.created_time,
        createdCase.updated_time,
        createdCase.created_time AS case_type_change_time,
        _workflow_id AS workflow_id
      FROM createdCase
      JOIN public.user_profile AS assignee ON assignee.email = _datarow.data->>'assignee.email'
      RETURNING gather_case_id, id INTO _gather_case_id, _funeral_home_case_id;

      INSERT INTO public.case_note (gather_case_id, note, created_by, created_time, updated_by, updated_time)
      SELECT
        _gather_case_id,
        TRIM(_datarow.data->>'case_note'),
        assignee.id, -- created_by,
        (_datarow.data->>'created_time')::TIMESTAMP, -- created_time,
        assignee.id, -- updated_by,
        (_datarow.data->>'created_time')::TIMESTAMP -- updated_time,
      FROM public.gather_case AS gc
      JOIN public.user_profile AS assignee
        ON assignee.email = _datarow.data->>'assignee.email'
      WHERE gc.id = _gather_case_id
        AND NULLIF(TRIM(_datarow.data->>'case_note'), '') IS NOT NULL;
      -- Create a default album for this case
      INSERT INTO public.album (gather_case_id, type, name, created_by, created_time, updated_by, updated_time)
      SELECT gc.id, 'case', 'default album', fh_case.assignee_id, gc.created_time, fh_case.assignee_id, gc.created_time
      FROM public.gather_case AS gc
      JOIN public.funeral_home_case AS fh_case
        ON fh_case.gather_case_id = gc.id
      WHERE gc.id = _gather_case_id
        AND fh_case.funeral_home_id = gc.funeral_home_id; -- assuming owner FH for photo album

      PERFORM dataload.add_case_task(_gather_case_id, _funeral_home_case_id, _workflow_id, _funeral_home_id);
      PERFORM set_case_task_step_counts(_funeral_home_case_id);

      UPDATE dataload.datarow SET status = 'committed'::dataload.batch_status WHERE id = _datarow.id;
      RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message', FORMAT('Added new case %s', _gather_case_id),
        'gather_case_id', _gather_case_id);
    ELSE -- This case already exists , so update it
      UPDATE public.gather_case gc SET
        created_time = (_datarow.data->>'created_time')::TIMESTAMP,
        updated_time = NOW(),
        fname = _datarow.data->>'fname',
        mname = _datarow.data->>'mname',
        lname = _datarow.data->>'lname',
        suffix = _datarow.data->>'suffix',
        dob_date = NULLIF(_datarow.data->>'date_of_birth', ''),
        dod_start_date = NULLIF(_datarow.data->>'date_of_death', ''),
        dod_start_time = _datarow.data->>'time_of_death',
        created_by = assignee.id,
        updated_by = assignee.id,
        death_certificate = _datarow.data->'dc'
      FROM public.user_profile AS assignee
      WHERE gc.id = _gather_case_id
        AND assignee.email = _datarow.data->>'assignee.email';
      
      WITH fhCaseUpdates AS (
        SELECT
          fh_case.id,
          assignee.id AS assignee_id,
          gc.created_by,
          gc.updated_by,
          gc.created_time,
          gc.updated_time
        FROM public.gather_case AS gc
        JOIN public.funeral_home_case AS fh_case
          ON fh_case.gather_case_id = gc.id
        JOIN public.user_profile AS assignee
          ON assignee.email = _datarow.data->>'assignee.email'
        WHERE gc.id = _gather_case_id
          AND fh_case.funeral_home_id = gc.funeral_home_id -- assume owner FH
      )
      UPDATE public.funeral_home_case AS fh_case SET
        assignee_id = u.assignee_id,
        case_type = (_datarow.data->>'case_type')::public.case_type,
        created_by = u.created_by,
        updated_by = u.updated_by,
        case_type_change_by = u.assignee_id,
        created_time = u.created_time,
        updated_time = u.updated_time,
        case_type_change_time = u.created_time,
        workflow_id = _workflow_id
      FROM fhCaseUpdates AS u
      WHERE fh_case.id = u.id
      RETURNING fh_case.id INTO _funeral_home_case_id;

      SELECT INTO _note_id
        case_note.id
      FROM public.case_note
      WHERE case_note.gather_case_id = _gather_case_id
        AND TRIM(case_note.note) = TRIM(_datarow.data->>'case_note');
      IF _note_id IS NULL THEN
        INSERT INTO public.case_note (gather_case_id, note, created_by, created_time, updated_by, updated_time)
          SELECT
            _gather_case_id,
            TRIM(_datarow.data->>'case_note'),
            assignee.id, -- created_by,
            (_datarow.data->>'created_time')::TIMESTAMP, -- created_time,
            assignee.id, -- updated_by,
            (_datarow.data->>'created_time')::TIMESTAMP -- updated_time,
          FROM public.gather_case AS gc
          JOIN public.user_profile AS assignee
            ON assignee.email = _datarow.data->>'assignee.email'
          WHERE gc.id = _gather_case_id
            AND NULLIF(TRIM(_datarow.data->>'case_note'), '') IS NOT NULL;
      END IF;

      PERFORM dataload.add_case_task(_gather_case_id, _funeral_home_case_id, _workflow_id, _funeral_home_id);
      PERFORM set_case_task_step_counts(_funeral_home_case_id);
      UPDATE dataload.datarow SET status = 'committed'::dataload.batch_status WHERE id = _datarow.id;
      RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message', FORMAT('Updated case id %s', _gather_case_id),
        'gather_case_id', _gather_case_id);
    END IF;
  END IF;
  
END;
$process_row$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION dataload.process_entity_row (_batch_id INTEGER, _row_number INTEGER, _all_cases BOOLEAN DEFAULT FALSE)
  RETURNS JSONB AS $process_row$
DECLARE
  _datarow dataload.datarow;
  _gather_case_id INTEGER;
  _is_case_imported BOOLEAN;
  _entity_id INTEGER;
  _case_entity_id INTEGER;
  _dc_informant INTEGER;
  _dc_spouse INTEGER;
  _dc_father INTEGER;
  _dc_mother INTEGER;
  _address RECORD;
BEGIN
  SELECT INTO _datarow * FROM dataload.datarow WHERE batch_id = _batch_id AND row_number = _row_number LIMIT 1;
  IF _datarow.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Unable to find data row for batch_id=%s, row_number=%s', _batch_id, _row_number),
      'gather_case_id', NULL);
  ELSIF _datarow.status != 'staging'::dataload.batch_status THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Row status is not ''staging'' but already ''%s''', _datarow.status),
      'gather_case_id', NULL);
  ELSE
    -- See if this case already exists, and store the id if it does
    SELECT INTO
      _gather_case_id, _is_case_imported, _dc_informant, _dc_spouse, _dc_father, _dc_mother
      gc.id, gc.imported_time IS NOT NULL, dc_informant,  dc_spouse,  dc_father,  dc_mother
    FROM public.gather_case AS gc
    JOIN public.funeral_home_case AS fh_case
      ON fh_case.gather_case_id = gc.id
    JOIN dataload.batch AS b ON b.id = _datarow.batch_id
    WHERE fh_case.funeral_home_id = b.funeral_home_id
      AND fh_case.case_number = _datarow.data->>'case_number' -- case number has to match
      AND fh_case.deleted_time IS NULL -- ignore deleted cases
      AND gc.deleted_time IS NULL -- ignore deleted cases
    ORDER BY gc.id DESC
    LIMIT 1; -- only get one (we need to add a unique index on fh_id, case_number)

    IF _gather_case_id IS NULL THEN -- Case must exist
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'message', FORMAT('ERROR: no case exists for case_number ''%s''', _datarow.data->>'case_number'),
        'gather_case_id', NULL);
    ELSIF (_all_cases = FALSE) AND NOT _is_case_imported THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'message', FORMAT('ERROR: case number ''%s'' is not imported and does not allow imports', _datarow.data->>'case_number'),
        'gather_case_id', _gather_case_id);
    ELSE
      SELECT INTO _entity_id e.id
      FROM public.entity AS e
      JOIN public.case_entity AS ec
        ON ec.entity_id = e.id AND ec.gather_case_id = _gather_case_id
      WHERE e.type = 'person'
        AND ( -- Relaxed name matching only uses first and last name
          COALESCE(_datarow.data->>'match_name', 'false') = 'true'
          AND CONCAT_WS(' ', e.fname, e.lname) = CONCAT_WS(' ', _datarow.data->>'fname', _datarow.data->>'lname')
        )
        OR ( -- Normal matching is more string name, email, and phone
          COALESCE(e.email, '') = COALESCE(_datarow.data->>'email', '')
          AND COALESCE(e.phone, '') = COALESCE(_datarow.data->>'phone', '')
          AND e.fname = _datarow.data->>'fname'
          AND COALESCE(e.mname, '') = COALESCE(_datarow.data->>'mname', '')
          AND e.lname = _datarow.data->>'lname'
        )
      ORDER BY
        e.email = _datarow.data->>'email' DESC, -- Match email first
        e.phone = _datarow.data->>'phone' DESC, -- Match phone next
        e.id DESC -- Find the most recent if multiple
      LIMIT 1;

      IF _entity_id IS NULL THEN -- If the entity does not exist
        INSERT INTO public.entity (fname, mname, lname, email, phone, is_deceased, type) VALUES
        (
          _datarow.data->>'fname',
          _datarow.data->>'mname',
          _datarow.data->>'lname',
          NULLIF(_datarow.data->>'email', ''),
          NULLIF(_datarow.data->>'phone', ''),
          (CASE WHEN COALESCE(_datarow.data->>'is_deceased', 'false') = 'true' THEN TRUE ELSE FALSE END),
          'person'
        ) RETURNING id INTO _entity_id;

        INSERT INTO public.case_entity (
          entity_id, gather_case_id, created_by, relationship, relationship_type,
          relationship_alias, moderation_status, moderation_time, moderated_by, moderation_required
        )
        SELECT _entity_id, _gather_case_id, gc.created_by,
          (NULLIF(_datarow.data->>'relationship', ''))::public.entity_relationship,
          (NULLIF(_datarow.data->>'relationship_type', ''))::public.entity_relation_type,
          (NULLIF(_datarow.data->>'relationship_alias', '')),
          'approved'::public.moderation_status,
          NOW(), 0, FALSE
        FROM public.gather_case AS gc
        WHERE gc.id = _gather_case_id
        RETURNING id INTO _case_entity_id;
      ELSE -- If the entity already exists
        UPDATE public.entity SET
          fname = _datarow.data->>'fname',
          mname = _datarow.data->>'mname',
          lname = _datarow.data->>'lname',
          email = COALESCE(NULLIF(_datarow.data->>'email', ''), e.email),
          phone = COALESCE(NULLIF(_datarow.data->>'phone', ''), e.phone),
          is_deceased = (CASE WHEN COALESCE(_datarow.data->>'is_deceased', 'false') = 'true' THEN TRUE ELSE FALSE END)
        FROM public.entity e
        WHERE entity.id = _entity_id
          AND e.id = _entity_id;

        UPDATE public.case_entity SET
          relationship = (NULLIF(_datarow.data->>'relationship', ''))::public.entity_relationship,
          relationship_type = (NULLIF(_datarow.data->>'relationship_type', ''))::public.entity_relation_type,
          relationship_alias = (NULLIF(_datarow.data->>'relationship_alias', ''))
          WHERE entity_id = _entity_id
            AND gather_case_id = _gather_case_id
          RETURNING id INTO _case_entity_id;
      END IF;

      -- Update the entity's address if city is set
      IF TRIM(COALESCE(_datarow.data->>'city', '')) != ''
        AND TRIM(COALESCE(_datarow.data->>'state', '')) != '' THEN
        _address := (SELECT public.get_or_create_address(JSONB_BUILD_OBJECT(
          'address1', COALESCE(_datarow.data->>'address1', ''),
          'address2', COALESCE(_datarow.data->>'address2', ''),
          'city', COALESCE(_datarow.data->>'city', ''),
          'state', COALESCE(_datarow.data->>'state', ''),
          'postalCode', COALESCE(_datarow.data->>'postal_code', ''),
          'county', COALESCE(_datarow.data->>'county', ''),
          'country', COALESCE(_datarow.data->>'country', ''),
          'description', CONCAT_WS(', ',
              NULLIF(TRIM(_datarow.data->>'locationName'), ''),
              NULLIF(TRIM(_datarow.data->>'address1'), ''),
              NULLIF(TRIM(_datarow.data->>'address2'), ''),
              NULLIF(TRIM(_datarow.data->>'city'), ''),
              NULLIF(TRIM(_datarow.data->>'state'), ''),
              NULLIF(TRIM(_datarow.data->>'postal_code'), ''),
              NULLIF(TRIM(_datarow.data->>'country'), '')
            )
          )
        , NULL, FALSE));
        UPDATE public.entity SET home_address_id = _address.id WHERE id = _entity_id;
      ELSE
        UPDATE public.entity SET home_address_id = NULL WHERE id = _entity_id;
      END IF;

      -- Set entity as informant if marked as such
      IF COALESCE(_datarow.data->>'is_informant', 'false') = 'true' THEN
        UPDATE public.gather_case SET dc_informant = _case_entity_id WHERE id = _gather_case_id;
      ELSIF COALESCE(_dc_informant, 0) = _case_entity_id THEN
        -- If this entity was the informant, but is no longer, then drop informant
        UPDATE public.gather_case SET dc_informant = NULL WHERE id = _gather_case_id;
      END IF;

      -- Set entity as spouse if marked as such
      IF COALESCE(_datarow.data->>'relationship', '') IN ('husband', 'wife', 'spouse', 'partner', 'domesticPartner') THEN
        UPDATE public.gather_case SET dc_spouse = _case_entity_id WHERE id = _gather_case_id;
      ELSIF COALESCE(_dc_spouse, 0) = _case_entity_id THEN
        UPDATE public.gather_case SET dc_spouse = NULL WHERE id = _gather_case_id;
      END IF;

      -- Set entity as father if marked as such
      IF COALESCE(_datarow.data->>'relationship', '') = 'father' THEN
        UPDATE public.gather_case SET dc_father = _case_entity_id WHERE id = _gather_case_id;
      ELSIF COALESCE(_dc_father, 0) = _case_entity_id THEN
        UPDATE public.gather_case SET dc_father = NULL WHERE id = _gather_case_id;
      END IF;

      -- Set entity as mother if marked as such
      IF COALESCE(_datarow.data->>'relationship', '') = 'mother' THEN
        UPDATE public.gather_case SET dc_mother = _case_entity_id WHERE id = _gather_case_id;
      ELSIF COALESCE(_dc_mother, 0) = _case_entity_id THEN
        UPDATE public.gather_case SET dc_mother = NULL WHERE id = _gather_case_id;
      END IF;

      RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message', FORMAT('Entity %s', _entity_id),
        'gather_case_id', _gather_case_id);
    END IF;
  END IF;
END;
$process_row$
LANGUAGE plpgsql SECURITY DEFINER;

-- END APP-1361

CREATE FUNCTION dataload.process_rolodex_row (_batch_id INTEGER, _row_number INTEGER)
  RETURNS JSONB AS $process_row$
DECLARE
  _datarow dataload.datarow;
  _organization_id INTEGER;
  _entity_id INTEGER;
  _funeral_home_id INTEGER;
  _address RECORD;
BEGIN
  SELECT INTO _datarow * FROM dataload.datarow WHERE batch_id = _batch_id AND row_number = _row_number LIMIT 1;
  IF _datarow.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Unable to find data row for batch_id=%s, row_number=%s', _batch_id, _row_number),
      'gather_case_id', NULL);
  ELSIF _datarow.status != 'staging'::dataload.batch_status THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Row status is not ''staging'' but already ''%s''', _datarow.status),
      'gather_case_id', NULL);
  ELSIF _datarow.data->>'contact.fname' = '' AND _datarow.data->>'org.name' = '' THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'message', FORMAT('ERROR: Neither an org nor a contact were provided %s', JSONB_PRETTY(_datarow.data)),
        'gather_case_id', NULL);
  ELSE
    -- Get the funeral home id from the batch table
    SELECT INTO _funeral_home_id funeral_home_id FROM dataload.batch where id = _batch_id;

    -- Try to find an existing org
    IF _datarow.data->>'org.external_id' != '' THEN
        SELECT INTO
            _organization_id
            org.id
        FROM public.organization AS org
        WHERE org.funeral_home_id = _funeral_home_id
            AND org.deleted_time IS NULL -- ignore deleted organizations
            AND org.external_id = _datarow.data->>'org.external_id'
        ORDER BY org.id DESC
        LIMIT 1; -- Only get the most recent org
    END IF;

    -- If there is no org yet, then insert one
    IF _organization_id IS NULL THEN
        INSERT INTO public.organization (external_id, name, type, other_text, email, phone, fax_number, website_url, notes, rank_in_org, created_by, updated_by, funeral_home_id)
        VALUES (
            _datarow.data->>'org.external_id',
            _datarow.data->>'org.name',
            (_datarow.data->>'org.type')::public.org_type,
            _datarow.data->>'org.other_text',
            _datarow.data->>'org.email',
            _datarow.data->>'org.phone',
            _datarow.data->>'org.fax',
            _datarow.data->>'org.website_url',
            _datarow.data->>'org.notes',
            (_datarow.data->>'org.rank_in_org')::INTEGER,
            0,
            0,
            _funeral_home_id
        ) RETURNING id INTO _organization_id;
    ELSE -- otherwise update the existing one
        UPDATE public.organization AS org SET
            name = _datarow.data->>'org.name',
            other_text = _datarow.data->>'org.other_text',
            email = _datarow.data->>'org.email',
            phone = _datarow.data->>'org.phone',
            fax_number = _datarow.data->>'org.fax',
            website_url = _datarow.data->>'org.website_url',
            notes = _datarow.data->>'org.notes',
            rank_in_org = (_datarow.data->>'org.rank_in_org')::INTEGER,
            updated_by = 0,
            updated_time = NOW()
        WHERE org.id = _organization_id;
    END IF;

      -- Update the organization's address if any of the fields are set
    IF TRIM(COALESCE(_datarow.data->>'org.address.city', '')) != ''
      OR TRIM(COALESCE(_datarow.data->>'org.address.state', '')) != ''
      OR TRIM(COALESCE(_datarow.data->>'org.address.postalCode', '')) != ''
      OR TRIM(COALESCE(_datarow.data->>'org.address.address1', '')) != ''
      THEN
      _address := (SELECT public.get_or_create_address(JSONB_BUILD_OBJECT(
        'address1', COALESCE(_datarow.data->>'org.address.address1', ''),
        'address2', COALESCE(_datarow.data->>'org.address.address2', ''),
        'city', COALESCE(_datarow.data->>'org.address.city', ''),
        'state', COALESCE(_datarow.data->>'org.address.state', ''),
        'postalCode', COALESCE(_datarow.data->>'org.address.postalCode', ''),
        'county', COALESCE(_datarow.data->>'org.address.county', ''),
        'country', COALESCE(_datarow.data->>'org.address.country', ''),
        'description', CONCAT_WS(', ',
            NULLIF(TRIM(_datarow.data->>'org.address.locationName'), ''),
            NULLIF(TRIM(_datarow.data->>'org.address.address1'), ''),
            NULLIF(TRIM(_datarow.data->>'org.address.address2'), ''),
            NULLIF(TRIM(_datarow.data->>'org.address.city'), ''),
            NULLIF(TRIM(_datarow.data->>'org.address.state'), ''),
            NULLIF(TRIM(_datarow.data->>'org.address.postalCode'), ''),
            NULLIF(TRIM(_datarow.data->>'org.address.country'), '')
          )
        )
      , NULL, FALSE));
      UPDATE public.organization SET address_id = _address.id WHERE id = _organization_id;
    ELSE
      UPDATE public.organization SET address_id = NULL WHERE id = _organization_id;
    END IF;

    -- If a contact was supplied
    IF _datarow.data->>'contact.external_id' != '' THEN
        -- Try to find an existing contact
        SELECT INTO
            _entity_id
            e.id
        FROM public.entity AS e
        WHERE e.external_id = _datarow.data->>'contact.external_id'
          AND e.organization_id = _organization_id
        ORDER BY e.id DESC
        LIMIT 1;

        IF _entity_id IS NULL THEN
            INSERT INTO public.entity (
              external_id, org_role, title, fname, lname,
              email, phone, fax_number,
              organization_id, type) VALUES
            (
              _datarow.data->>'contact.external_id',
              _datarow.data->>'contact.role',
              NULLIF(_datarow.data->>'contact.title', ''),
              _datarow.data->>'contact.fname',
              _datarow.data->>'contact.lname',
              NULLIF(_datarow.data->>'contact.email', ''),
              NULLIF(_datarow.data->>'contact.phone', ''),
              NULLIF(_datarow.data->>'contact.fax', ''),
              _organization_id,
              'person'
            ) RETURNING id INTO _entity_id;
        ELSE
          UPDATE public.entity SET
            org_role = _datarow.data->>'contact.role',
            title = NULLIF(_datarow.data->>'contact.title', ''),
            fname = _datarow.data->>'contact.fname',
            lname = _datarow.data->>'contact.lname',
            email = NULLIF(_datarow.data->>'contact.email', ''),
            phone = NULLIF(_datarow.data->>'contact.phone', ''),
            fax_number = NULLIF(_datarow.data->>'contact.fax', '')
          WHERE id = _entity_id;
        END IF;

        -- Update the entity's address if any of the fields are set
        IF TRIM(COALESCE(_datarow.data->>'contact.address.city', '')) != ''
          OR TRIM(COALESCE(_datarow.data->>'contact.address.state', '')) != ''
          OR TRIM(COALESCE(_datarow.data->>'contact.address.postalCode', '')) != ''
          OR TRIM(COALESCE(_datarow.data->>'contact.address.address1', '')) != ''
          THEN
          _address := (SELECT public.get_or_create_address(JSONB_BUILD_OBJECT(
            'address1', COALESCE(_datarow.data->>'contact.address.address1', ''),
            'address2', COALESCE(_datarow.data->>'contact.address.address2', ''),
            'city', COALESCE(_datarow.data->>'contact.address.city', ''),
            'state', COALESCE(_datarow.data->>'contact.address.state', ''),
            'postalCode', COALESCE(_datarow.data->>'contact.address.postalCode', ''),
            'county', COALESCE(_datarow.data->>'contact.address.county', ''),
            'country', COALESCE(_datarow.data->>'contact.address.country', ''),
            'description', CONCAT_WS(', ',
                NULLIF(TRIM(_datarow.data->>'contact.address.locationName'), ''),
                NULLIF(TRIM(_datarow.data->>'contact.address.address1'), ''),
                NULLIF(TRIM(_datarow.data->>'contact.address.address2'), ''),
                NULLIF(TRIM(_datarow.data->>'contact.address.city'), ''),
                NULLIF(TRIM(_datarow.data->>'contact.address.state'), ''),
                NULLIF(TRIM(_datarow.data->>'contact.address.postalCode'), ''),
                NULLIF(TRIM(_datarow.data->>'contact.address.country'), '')
              )
            )
          , NULL, FALSE));
          UPDATE public.entity SET home_address_id = _address.id WHERE id = _entity_id;
        ELSE
          UPDATE public.entity SET home_address_id = NULL WHERE id = _entity_id;
        END IF;

    END IF;


    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'message', FORMAT('Organization %s and entity is %s', COALESCE(_organization_id::TEXT, 'NONE'), COALESCE(_entity_id::TEXT, 'NONE')),
      'gather_case_id', NULL);
END IF;
END;
$process_row$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION dataload.process_event_row (_batch_id INTEGER, _row_number INTEGER, _all_cases BOOLEAN DEFAULT FALSE)
  RETURNS JSONB AS $process_row$
DECLARE
  _datarow dataload.datarow;
  _gather_case_id INTEGER;
  _is_case_imported BOOLEAN;
  _event_id INTEGER;
BEGIN
  SELECT INTO _datarow * FROM dataload.datarow WHERE batch_id = _batch_id AND row_number = _row_number LIMIT 1;
  IF _datarow.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Unable to find data row for batch_id=%s, row_number=%s', _batch_id, _row_number),
      'gather_case_id', NULL);
  ELSIF _datarow.status != 'staging'::dataload.batch_status THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Row status is not ''staging'' but already ''%s''', _datarow.status),
      'gather_case_id', NULL);
  ELSE
    -- See if this case already exists, and store the id if it does
    SELECT INTO _gather_case_id, _is_case_imported
      gc.id, gc.imported_time IS NOT NULL
    FROM public.gather_case AS gc
    JOIN public.funeral_home_case AS fh_case
      ON fh_case.gather_case_id = gc.id
    JOIN dataload.batch AS b ON b.id = _datarow.batch_id
    WHERE fh_case.funeral_home_id = b.funeral_home_id
      AND fh_case.case_number = _datarow.data->>'case_number' -- case number has to match
      AND fh_case.deleted_time IS NULL -- ignore deleted cases
      AND gc.deleted_time IS NULL -- ignore deleted cases
    ORDER BY gc.id DESC
    LIMIT 1; -- only get one (we need to add a unique index on fh_id, case_number)

    IF _gather_case_id IS NULL THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'message', FORMAT('ERROR: case number ''%s'' Does not exist, you must import or create this case to add events', _datarow.data->>'case_number'),
        'gather_case_id', _gather_case_id);
    ELSEIF (_all_cases = FALSE) AND NOT _is_case_imported THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'message', FORMAT('ERROR: case number ''%s'' is not imported and does not allow update via import', _datarow.data->>'case_number'),
        'gather_case_id', _gather_case_id);
    ELSE
        -- check if event exists, store the id if so
        SELECT INTO _event_id e.id
        FROM public.event AS e
        JOIN public.gather_case AS gc ON gc.id = e.gather_case_id
        JOIN public.funeral_home_case AS fh_case ON fh_case.gather_case_id = gc.id
        WHERE gc.id = _gather_case_id
          AND TRIM(LOWER(e.name)) = TRIM(LOWER(_datarow.data->>'name'))
          AND gc.deleted_time IS NULL
          AND fh_case.deleted_time IS NULL;
    END IF;

    IF _event_id IS NULL THEN
        -- create the event
        INSERT INTO public.event (
          gather_case_id, name, event_type,
          start_time, end_time, message, is_private)
          SELECT
            _gather_case_id,
            _datarow.data->>'name',
            'custom'::public.event_type,
            (_datarow.data->>'start_time')::TIMESTAMP AT TIME ZONE COALESCE(fh_addr.timezone, 'America/Denver'),
            (_datarow.data->>'end_time')::TIMESTAMP AT TIME ZONE COALESCE(fh_addr.timezone, 'America/Denver'),
            _datarow.data->>'message',
            FALSE
          FROM dataload.batch AS b
          JOIN public.funeral_home AS fh ON fh.id = b.funeral_home_id
          JOIN public.address AS fh_addr ON fh_addr.id = fh.address_id
          WHERE b.id = _batch_id;

        UPDATE dataload.datarow SET status = 'committed'::dataload.batch_status WHERE id = _datarow.id;
        RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message', FORMAT('Added new event %s - %s for case#: %s', _event_id, _datarow.data->>'name', _datarow.data->>'case_number'),
        'gather_case_id', _gather_case_id);
    ELSE
        -- update existing event
        UPDATE public.event SET
            name = _datarow.data->>'name',
            start_time = (_datarow.data->>'start_time')::TIMESTAMP AT TIME ZONE COALESCE(fh_addr.timezone, 'America/Denver'),
            end_time = (_datarow.data->>'end_time')::TIMESTAMP AT TIME ZONE COALESCE(fh_addr.timezone, 'America/Denver'),
            message = _datarow.data->>'message'
        FROM dataload.batch AS b
        JOIN public.funeral_home AS fh ON fh.id = b.funeral_home_id
        JOIN public.address AS fh_addr ON fh_addr.id = fh.address_id
        WHERE b.id = _batch_id AND event.id = _event_id;

    END IF;
    UPDATE dataload.datarow SET status = 'committed'::dataload.batch_status WHERE id = _datarow.id;
    RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'message', FORMAT('Updated event %s - %s for case#: %s', _event_id, _datarow.data->>'name', _datarow.data->>'case_number'),
    'gather_case_id', _gather_case_id);

    END IF;
  END;
$process_row$
LANGUAGE plpgsql SECURITY DEFINER;



CREATE TYPE dataload.data_source AS ENUM (
  'cfs', 'funeralone', 'funeralinnovations', 'frontrunner',
  'batesville', 'frazer', 'funeraltech', 'other'
);

-- Keep track of when we loaded gather_case data from various vendors
CREATE TABLE dataload.gather_case_external_id (
  gather_case_id          INTEGER NOT NULL REFERENCES public.gather_case(id),
  external_id             TEXT NOT NULL,
  data_source             dataload.data_source NOT NULL,
  imported_time           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE                  (gather_case_id, data_source),
  UNIQUE                  (external_id, data_source)
);

CREATE TYPE dataload.scrape_status AS ENUM ('NONE', 'DOWNLOADING', 'DONE', 'ERROR');
CREATE TYPE dataload.scrape_problem AS ENUM ('NONE', 'UNMATCHED', 'DUPLICATE', 'AMBIGUOUS');

CREATE TABLE dataload.obit_scrape (
  id                      SERIAL PRIMARY KEY,
  data_source             dataload.data_source NOT NULL,
  funeral_homes           INTEGER[],
  created_time            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE dataload.external_case (
  id                      SERIAL PRIMARY KEY,
  obit_scrape_id          INTEGER NOT NULL REFERENCES dataload.obit_scrape(id),
  external_id             TEXT NOT NULL,
  gather_case_id          INTEGER REFERENCES public.gather_case(id),
  matched                 INTEGER NOT NULL DEFAULT 0,
  problem                 dataload.scrape_problem NOT NULL DEFAULT 'UNMATCHED',
  description             TEXT,
  data                    JSONB NOT NULL,
  key1                    TEXT NOT NULL,
  key2                    TEXT NOT NULL,
  key3                    TEXT NOT NULL,
  key4                    TEXT NOT NULL,
  key5                    TEXT NOT NULL,
  key6                    TEXT NOT NULL,
  photo_status            dataload.scrape_status NOT NULL DEFAULT 'NONE',
  obituary_status         dataload.scrape_status NOT NULL DEFAULT 'NONE',
  memory_status           dataload.scrape_status NOT NULL DEFAULT 'NONE',
  link_status             dataload.scrape_status NOT NULL DEFAULT 'NONE',
  UNIQUE                  (obit_scrape_id, external_id)
);

CREATE INDEX idx_external_case_scrape_id ON dataload.external_case(obit_scrape_id);
CREATE INDEX idx_external_case_key1 ON dataload.external_case(obit_scrape_id, key1);
CREATE INDEX idx_external_case_key2 ON dataload.external_case(obit_scrape_id, key2);
CREATE INDEX idx_external_case_key3 ON dataload.external_case(obit_scrape_id, key3);
CREATE INDEX idx_external_case_key4 ON dataload.external_case(obit_scrape_id, key4);
CREATE INDEX idx_external_case_key5 ON dataload.external_case(obit_scrape_id, key5);
CREATE INDEX idx_external_case_key6 ON dataload.external_case(obit_scrape_id, key6);

CREATE TABLE dataload.internal_case (
  obit_scrape_id          INTEGER NOT NULL REFERENCES dataload.obit_scrape(id),
  id                      INTEGER NOT NULL REFERENCES public.gather_case(id),
  external_case_id        INTEGER REFERENCES dataload.external_case(id),
  key1                    TEXT, -- fname lname dod
  key2                    TEXT, -- lname dod
  key3                    TEXT, -- fname.3 lastToken(lname).3 dod
  key4                    TEXT, -- fname dod
  key5                    TEXT, -- fname lname
  key6                    TEXT -- fname.3 lname.3 dod
);

CREATE INDEX idx_internal_case_scrape_id ON dataload.internal_case(obit_scrape_id);
CREATE INDEX idx_internal_case_key1 ON dataload.internal_case(obit_scrape_id, key1);
CREATE INDEX idx_internal_case_key2 ON dataload.internal_case(obit_scrape_id, key2);
CREATE INDEX idx_internal_case_key3 ON dataload.internal_case(obit_scrape_id, key3);
CREATE INDEX idx_internal_case_key4 ON dataload.internal_case(obit_scrape_id, key4);
CREATE INDEX idx_internal_case_key5 ON dataload.internal_case(obit_scrape_id, key5);
CREATE INDEX idx_internal_case_key6 ON dataload.internal_case(obit_scrape_id, key6);

ALTER TABLE photo ADD COLUMN data_source dataload.data_source;
ALTER TABLE memory ADD COLUMN data_source dataload.data_source;
ALTER TABLE obituary ADD COLUMN data_source dataload.data_source;
ALTER TABLE obituary_link ADD COLUMN data_source dataload.data_source;

-- Start a new dataload process by creating an obit_scrape record and populating the internal_case table
CREATE FUNCTION dataload.init_obit_scrape(_data_source dataload.data_source, _funeral_homes INTEGER[]) RETURNS INTEGER AS $init_obit_scrape$
  DECLARE
    _scrape_id INTEGER;
  BEGIN
  
  INSERT INTO dataload.obit_scrape (data_source, funeral_homes)
    VALUES (_data_source, _funeral_homes)
    RETURNING id INTO _scrape_id;

  INSERT INTO dataload.internal_case (obit_scrape_id, id, external_case_id, key1, key2, key3, key4, key5, key6)
  SELECT
      _scrape_id AS obit_scrape_id,
      gc.id AS gather_case_id,
      NULL AS external_case_id,
      -- KEY1 First name, last name, date of death
      dataload.clean_name(gc.fname, gc.lname, gc.dod_start_date) AS key1,
      -- KEY2 first 3 chars of fist and last, date of death
      dataload.clean_name(SUBSTRING(gc.fname FROM 1 FOR 3), SUBSTRING(gc.lname FROM 1 FOR 3), gc.dod_start_date) AS key2,
      -- KEY3 first 3 chars of first and last token of last, date of death
      dataload.clean_name(SUBSTRING(gc.fname FROM 1 FOR 3), SUBSTRING(SUBSTRING(gc.lname FROM '[^\s-]*$') FROM 1 FOR 3), gc.dod_start_date) AS key3,
      -- KEY4 last token of last name and date of death
      dataload.clean_name(SUBSTRING(gc.lname FROM '[^\s-]*$'), gc.dod_start_date, NULL) AS key4,
      -- KEY5 first token of first name and date of death
      dataload.clean_name(SUBSTRING(gc.fname FROM '^[^\s-]*'), gc.dod_start_date, NULL) AS key5,
      -- KEY6 first name and last name
      dataload.clean_name(gc.fname, gc.lname, NULL) AS key6
  FROM public.gather_case AS gc
  JOIN public.funeral_home_case AS fh_case
    ON fh_case.gather_case_id = gc.id
  WHERE
    gc.funeral_home_id = ANY(_funeral_homes)
    AND fh_case.funeral_home_id = gc.funeral_home_id -- assuming owner FH for dataloads
    AND fh_case.case_type IN ('at-need', 'trade', 'one-off')
    AND fh_case.deleted_time IS NULL
    AND gc.deleted_time IS NULL
    AND gc.is_test = FALSE
  ;

  RETURN _scrape_id;
  END;
$init_obit_scrape$ LANGUAGE plpgsql SECURITY definer;

-- INLINE SCALAR FUNCTION - should be very performant... https://wiki.postgresql.org/wiki/Inlining_of_SQL_functions
CREATE OR REPLACE FUNCTION dataload.clean_name(_first TEXT, _middle TEXT, _last TEXT) RETURNS TEXT AS $clean_name$
    SELECT CONCAT_WS('|',
      CASE WHEN _first IS NULL THEN NULL ELSE REGEXP_REPLACE(LOWER(_first), '[\s\-''\*\(\)\.\"]', '', 'g') END,
      CASE WHEN _middle IS NULL THEN NULL ELSE REGEXP_REPLACE(LOWER(_middle), '[\s\-''\*\(\)\.\"]', '', 'g') END,
      CASE WHEN _last IS NULL THEN NULL ELSE REGEXP_REPLACE(LOWER(_last), '[\s\-''\*\(\)\.\"]', '', 'g') END
    );
$clean_name$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION public.clean_name(_first TEXT, _middle TEXT, _last TEXT) RETURNS TEXT AS $clean_name$
    SELECT dataload.clean_name(_first, _middle, _last);
$clean_name$ LANGUAGE SQL IMMUTABLE SECURITY definer;

CREATE FUNCTION dataload.process_obit_row (_batch_id INTEGER, _obit_scrape_id INTEGER, _row_number INTEGER)
  RETURNS JSONB AS $process_row$
DECLARE
  _datarow dataload.datarow;
  _external_case_id INTEGER;
BEGIN
  SELECT INTO _datarow * FROM dataload.datarow WHERE batch_id = _batch_id AND row_number = _row_number LIMIT 1;
  IF _datarow.id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Unable to find data row for batch_id=%s, row_number=%s', _batch_id, _row_number),
      'gather_case_id', NULL);
  ELSIF _datarow.status != 'staging'::dataload.batch_status THEN
    RETURN JSONB_BUILD_OBJECT(
      'success', FALSE,
      'message', FORMAT('ERROR: Row status is not ''staging'' but already ''%s''', _datarow.status),
      'gather_case_id', NULL);
  ELSE
    -- See if this external ID already exists, and update the record if it does
    SELECT INTO _external_case_id id
    FROM dataload.external_case
    WHERE external_id = _datarow.data->>'external_id' -- external ID has to match
      AND obit_scrape_id = _obit_scrape_id
    ;

    IF _external_case_id IS NULL THEN -- This obit record doesn't already exist, so insert it now
      INSERT INTO dataload.external_case (
        obit_scrape_id, external_id, data,
        key1, key2, key3, key4, key5, key6)
      SELECT
        _obit_scrape_id,
        _datarow.data->'decedent'->>'external_id',
        _datarow.data,
      -- KEY1 First name, last name, date of death
      dataload.clean_name(_datarow.data->'decedent'->'name'->>'first_name', _datarow.data->'decedent'->'name'->>'last_name', _datarow.data->'decedent'->>'date_of_death') AS key1,
      -- KEY2 first 3 chars of fist and last, date of death
      dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'first_name' FROM 1 FOR 3), SUBSTRING(_datarow.data->'decedent'->'name'->>'last_name' FROM 1 FOR 3), _datarow.data->'decedent'->>'date_of_death') AS key2,
      -- KEY3 first 3 chars of first and last token of last, date of death
      dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'first_name' FROM 1 FOR 3), SUBSTRING(SUBSTRING(_datarow.data->'decedent'->'name'->>'last_name' FROM '[^\s-]*$') FROM 1 FOR 3), _datarow.data->'decedent'->>'date_of_death') AS key3,
      -- KEY4 last token of last name and date of death
      dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'last_name' FROM '[^\s-]*$'), _datarow.data->'decedent'->>'date_of_death', NULL) AS key4,
      -- KEY5 first token of first name and date of death
      dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'first_name' FROM '^[^\s-]*'), _datarow.data->'decedent'->>'date_of_death', NULL) AS key5,
      -- KEY6 first name and last name
      dataload.clean_name(_datarow.data->'decedent'->'name'->>'first_name', _datarow.data->'decedent'->'name'->>'last_name', NULL) AS key6
      FROM dataload.batch AS b
      WHERE b.id = _batch_id
      RETURNING id INTO _external_case_id;

      UPDATE dataload.datarow SET status = 'committed'::dataload.batch_status WHERE id = _datarow.id;

      RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message', FORMAT('Added new external case %s', _external_case_id),
        'gather_case_id', NULL);
    ELSE -- This scraped obit match record already exists , so updated it
      UPDATE dataload.external_case SET
        data = _datarow.data,
      -- KEY1 First name, last name, date of death
      key1 = dataload.clean_name(_datarow.data->'decedent'->'name'->>'first_name', _datarow.data->'decedent'->'name'->>'last_name', _datarow.data->'decedent'->>'date_of_death'),
      -- KEY2 first 3 chars of fist and last, date of death
      key2 = dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'first_name' FROM 1 FOR 3), SUBSTRING(_datarow.data->'decedent'->'name'->>'last_name' FROM 1 FOR 3), _datarow.data->'decedent'->>'date_of_death'),
      -- KEY3 first 3 chars of first and last token of last, date of death
      key3 = dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'first_name' FROM 1 FOR 3), SUBSTRING(SUBSTRING(_datarow.data->'decedent'->'name'->>'last_name' FROM '[^\s-]*$') FROM 1 FOR 3), _datarow.data->'decedent'->>'date_of_death'),
      -- KEY4 last token of last name and date of death
      key4 = dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'last_name' FROM '[^\s-]*$'), _datarow.data->'decedent'->>'date_of_death', NULL),
      -- KEY5 first token of first name and date of death
      key5 = dataload.clean_name(SUBSTRING(_datarow.data->'decedent'->'name'->>'first_name' FROM '^[^\s-]*'), _datarow.data->'decedent'->>'date_of_death', NULL),
      -- KEY6 first name and last name
      key6 = dataload.clean_name(_datarow.data->'decedent'->'name'->>'first_name', _datarow.data->'decedent'->'name'->>'last_name', NULL)
      WHERE id = _external_case_id;

      UPDATE dataload.datarow SET status = 'committed'::dataload.batch_status WHERE id = _datarow.id;

      RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'message', FORMAT('Updated external case %s', _external_case_id),
        'gather_case_id', NULL);
    END IF;
  END IF;
END;
$process_row$
LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION get_or_create_address(longAddress JSONB, tz TEXT, useDescription BOOLEAN) RETURNS address AS $get_or_create_address$
  DECLARE
    existing_record RECORD;
    new_record RECORD;
    updated_record RECORD;
  BEGIN

    IF (longAddress IS NULL) THEN
      RETURN NULL;
    END IF;
  
    SELECT DISTINCT INTO existing_record
      a.*
    FROM public.address AS a
    WHERE
      (NULLIF(longAddress->>'googlePlaceID', '') IS NOT NULL AND a.long_address->>'googlePlaceID' = longAddress->>'googlePlaceID')
      OR (
        COALESCE(a.address1, '') = COALESCE(longAddress->>'address1', '') AND
        COALESCE(a.address2, '') = COALESCE(longAddress->>'address2', '') AND
        COALESCE(a.city, '') = COALESCE(longAddress->>'city', '') AND
        COALESCE(a.state, '') = COALESCE(longAddress->>'state', '') AND
        COALESCE(a.country, '') = COALESCE(longAddress->>'country', '') AND
        COALESCE(a.postal_code, '') = COALESCE(longAddress->>'postalCode', '') AND
        COALESCE(a.timezone, '') = COALESCE(tz, '') AND
        COALESCE(a.description, '') = COALESCE(longAddress->>'description', '') AND
        a.use_description = COALESCE(useDescription, FALSE)
      )
    ORDER BY a.id;

    IF (existing_record.id IS NULL) THEN
      INSERT INTO public.address (address1, address2, city, state, country, postal_code, timezone, description, long_address, use_description) VALUES (
        COALESCE(longAddress->>'address1', ''),
        NULLIF(longAddress->>'address2', ''),
        COALESCE(longAddress->>'city', ''),
        COALESCE(longAddress->>'state', ''),
        NULLIF(longAddress->>'country', ''),
        NULLIF(longAddress->>'postalCode', ''),
        NULLIF(tz, ''),
        COALESCE(longAddress->>'description', ''),
        longAddress,
        useDescription
      ) RETURNING * INTO new_record;
      RETURN new_record;

    ELSIF (NULLIF(longAddress->>'googlePlaceID', '') IS NOT NULL) THEN
      UPDATE public.address SET
        address1 = COALESCE(longAddress->>'address1', ''),
        address2 = NULLIF(longAddress->>'address2', ''),
        city = COALESCE(longAddress->>'city', ''),
        state = COALESCE(longAddress->>'state', ''),
        country = NULLIF(longAddress->>'country', ''),
        postal_code = NULLIF(longAddress->>'postalCode', ''),
        timezone = NULLIF(tz, ''),
        description = COALESCE(longAddress->>'description', ''),
        long_address = longAddress,
        use_description = useDescription
      WHERE id = existing_record.id
      RETURNING * INTO updated_record;
      RETURN updated_record;

    ELSE
      RETURN existing_record;
    END IF;
  END;
$get_or_create_address$ LANGUAGE plpgsql;


CREATE FUNCTION public.deactivate_app_user(targetText TEXT) RETURNS void
AS $deactivateAppUser$
DECLARE
        -- vars here
        targetEmail TEXT;
        targetPhone TEXT;
        origUserProfile RECORD;
        origEntity RECORD;
        newEmail TEXT;
        newPass TEXT;
BEGIN

    -- IF (targetText ~ '^\+1\d{10}$') THEN
    IF (targetText LIKE '%@%') THEN
        RAISE NOTICE 'trying email address';
        SELECT * INTO origUserProfile FROM user_profile WHERE email = targetText;
    ELSE 
        RAISE NOTICE 'Trying phone number';
        SELECT * INTO origUserProfile FROM user_profile WHERE phone = targetText;
    END IF;
    SELECT * INTO origEntity FROM entity WHERE id = origUserProfile.entity_id;
    newEmail := 'user_deleted+' || origUserProfile.id || '@gather.app';
    newPass := 'NOTSET';
    IF origUserProfile IS NULL THEN
        RAISE EXCEPTION 'User profile NOT found for %', targetText
            USING HINT = 'Please verify the email address or phone number';
    ELSE
        RAISE NOTICE '***********************************************';
        RAISE NOTICE '*     Deactivation Details                    *';
        RAISE NOTICE '***********************************************';
        RAISE NOTICE '       EntityID: %', origEntity.id;
        RAISE NOTICE '  UserProfileId: %', origUserProfile.id;
        RAISE NOTICE ' Original  Pass: %', origUserProfile.password;
        RAISE NOTICE ' Original Email: %', origUserProfile.email;
        RAISE NOTICE ' Original Phone: %', origUserProfile.phone;
        RAISE NOTICE '';
        RAISE NOTICE '  NEW  Pass: %', newPass;
        RAISE NOTICE '  NEW Email: %', newEmail;
        RAISE NOTICE '  NEW Phone: NULL';
        RAISE NOTICE '***********************************************';

        RAISE NOTICE '';
        RAISE NOTICE '';

        RAISE NOTICE '***********************************************';
        RAISE NOTICE '*  To RESTORE THIS USER                       *';
        RAISE NOTICE '***********************************************';
        IF (origUserProfile.phone IS NULL) THEN
            RAISE NOTICE ' UPDATE entity SET email = ''%'' WHERE id = % ', origEntity.email, origEntity.id;
            RAISE NOTICE ' UPDATE user_profile SET deleted_time = NULL, password = ''%'' WHERE id = % ', origUserProfile.password, origUserProfile.id;
        ELSE 
            RAISE NOTICE ' UPDATE entity SET email = ''%'', phone = ''%'' WHERE id = % ', origEntity.email, origEntity.phone, origEntity.id;
            RAISE NOTICE ' UPDATE user_profile SET deleted_time = NULL, password = ''%'' WHERE id = % ', origUserProfile.password, origUserProfile.id;
        END IF;
        RAISE NOTICE '***********************************************';
        UPDATE entity SET email = newEmail, phone = null WHERE id = origEntity.id;
        UPDATE user_profile SET deleted_time = CURRENT_TIMESTAMP, password = newPass WHERE id = origUserProfile.id;
        UPDATE user_session SET token_expires = CURRENT_TIMESTAMP WHERE user_profile_id = origUserProfile.id;
        DELETE FROM deep_link WHERE user_id = origUserProfile.id;
    END IF;     

END;
$deactivateAppUser$
LANGUAGE 'plpgsql' 
SECURITY DEFINER
;

-- Merge two entity records
-- If target field is NULL and source has value, use source value
-- If source field is NULL and target has value, keep target value
-- For required fields, prefer source over target if both have values since this was presumably added by the FH or family user
-- Ignore rolodex related fields (org_role, organization_id)
CREATE OR REPLACE FUNCTION public.merge_entities(
    target_entity_id INTEGER, -- old
    source_entity_id INTEGER, -- new
    target_gather_case_id INTEGER
) RETURNS JSONB AS $mergeEntities$
DECLARE
    _target_entity RECORD;
    _source_entity RECORD;
    _target_funeral_home_case_id INTEGER;
    _target_case_entity_id INTEGER;
    _source_case_entity_id INTEGER;
BEGIN
    -- Get target entity, case entity records - this is the entity that will be updated
    SELECT * INTO _target_entity FROM entity WHERE id = target_entity_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Could not find target entity with ID %', target_entity_id;
    END IF;
    SELECT id INTO _target_case_entity_id FROM case_entity WHERE entity_id = target_entity_id AND gather_case_id = target_gather_case_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Could not find target case entity with ID %', target_entity_id;
    END IF;
    
    -- Get source entity, case entity records - this is the entity that will be merged into the target entity
    SELECT * INTO _source_entity FROM entity WHERE id = source_entity_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Could not find source entity with ID %', source_entity_id;
    END IF;
    SELECT id INTO _source_case_entity_id FROM case_entity WHERE entity_id = source_entity_id AND gather_case_id = target_gather_case_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Could not find source case entity with ID %', source_entity_id;
    END IF;

    -- Get funeral home case id so we can update payment entity references
    SELECT id INTO _target_funeral_home_case_id FROM funeral_home_case WHERE gather_case_id = target_gather_case_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Funeral home case with ID % not found', target_gather_case_id;
    END IF;
    
    -- Update (merge) target entity
    UPDATE entity SET
        external_id = COALESCE(NULLIF(_target_entity.external_id, ''), _source_entity.external_id),
        title = COALESCE(NULLIF(_target_entity.title, ''), _source_entity.title),
        -- fname NOT NULL
        mname = COALESCE(NULLIF(_target_entity.mname, ''), _source_entity.mname),
        -- lname NOT NULL
        email = COALESCE(NULLIF(_target_entity.email, ''), _source_entity.email),
        phone = COALESCE(NULLIF(_target_entity.phone, ''), _source_entity.phone),
        work_phone = COALESCE(NULLIF(_target_entity.work_phone, ''), _source_entity.work_phone),
        home_phone = COALESCE(NULLIF(_target_entity.home_phone, ''), _source_entity.home_phone),
        -- type NOT NULL
        home_address_id = COALESCE(_target_entity.home_address_id, _source_entity.home_address_id),
        billing_address_id = COALESCE(_target_entity.billing_address_id, _source_entity.billing_address_id),
        -- is_deceased NOT NULL
        photo_view_id = COALESCE(_target_entity.photo_view_id, _source_entity.photo_view_id),
        state_license_number = COALESCE(NULLIF(_target_entity.state_license_number, ''), _source_entity.state_license_number),
        fax_number = COALESCE(NULLIF(_target_entity.fax_number, ''), _source_entity.fax_number),
        suffix = COALESCE(NULLIF(_target_entity.suffix, ''), _source_entity.suffix)
    WHERE id = source_entity_id;

    -- Update dc references (informant, father, mother, spouse)
    UPDATE gather_case SET
        dc_informant = CASE 
            WHEN dc_informant = _target_case_entity_id THEN _source_case_entity_id
            ELSE dc_informant
        END,
        dc_father = CASE 
            WHEN dc_father = _target_case_entity_id THEN _source_case_entity_id
            ELSE dc_father
        END,
        dc_mother = CASE 
            WHEN dc_mother = _target_case_entity_id THEN _source_case_entity_id
            ELSE dc_mother
        END,
        dc_spouse = CASE 
            WHEN dc_spouse = _target_case_entity_id THEN _source_case_entity_id
            ELSE dc_spouse
        END
    WHERE id = target_gather_case_id;

    -- Update payment entity references
    UPDATE payment SET
        payer = source_entity_id WHERE payer = target_entity_id AND funeral_home_case_id = _target_funeral_home_case_id;

    -- Remove the target case entity
    DELETE FROM case_entity WHERE id = _target_case_entity_id AND gather_case_id = target_gather_case_id;
    
    RAISE NOTICE 'Successfully merged entity % into entity %', source_entity_id, target_entity_id;
    RETURN JSONB_BUILD_OBJECT(
        'source_entity', _source_entity,
        'target_entity', _target_entity
    );
END;
$mergeEntities$
LANGUAGE 'plpgsql'
;

CREATE OR REPLACE FUNCTION public.fill_case_variables(target_str TEXT, case_fname TEXT, case_funeral_home_name TEXT) RETURNS TEXT AS $fill_case_variables$
    SELECT REGEXP_REPLACE(REGEXP_REPLACE(target_str, '\{\{case\.fname\}\}', case_fname, 'g'), '\{\{case\.funeral_home_name\}\}', case_funeral_home_name, 'g')
$fill_case_variables$ LANGUAGE SQL IMMUTABLE;

-- APP-2801 
CREATE OR REPLACE FUNCTION get_remember_page_url ( funeral_home_id INTEGER ) 
RETURNS TEXT AS $$
    WITH website_details AS (
        SELECT DISTINCT 
        fhw.funeral_home_id,
        w.url AS website_url
        FROM funeral_home_website fhw
        JOIN funeral_home fh ON fhw.funeral_home_id = fh.id
        JOIN feature f ON f.key = 'FULL_REMEMBER_PAGE'
        LEFT JOIN feature_config fc ON f.key = fc.feature AND fc.funeral_home_id = fh.id
        LEFT JOIN website w ON fhw.website_id = w.id AND  w.vendor = 'gather'
        WHERE w.launched_time IS NOT NULL
        AND w.deleted_time IS NULL
        AND COALESCE(fc.enabled, f.default_state) = TRUE
        AND fh.id = $1
    )
    SELECT CASE WHEN wd.website_url IS NOT NULL 
        THEN CONCAT(RTRIM(fh.website_url, '/') , '/obituaries/')
    ELSE 
        CONCAT(rtrim(appurl.value, '/'), '/remember/')
    END 
    FROM funeral_home fh 
    LEFT JOIN website_details wd ON fh.id = wd.funeral_home_id
    JOIN environment appurl ON appurl.key = 'appUrl'
    WHERE fh.id = $1;
$$ LANGUAGE sql STABLE;

ALTER TABLE public.gather_case
    ADD COLUMN match_key_1 TEXT GENERATED ALWAYS AS (
        clean_name(fname, lname, dob_date)
    ) STORED,
    ADD COLUMN match_key_2 TEXT GENERATED ALWAYS AS (
        clean_name(lname, dob_date, NULL)
    ) STORED,
    ADD COLUMN match_key_3 TEXT GENERATED ALWAYS AS (
        clean_name(fname, SUBSTRING(mname FROM 1 FOR 1), lname)
    ) STORED,
    ADD COLUMN match_key_4 TEXT GENERATED ALWAYS AS (
        clean_name(fname, lname, NULL)
    ) STORED,
    ADD COLUMN dod_datetime TIMESTAMP WITH TIME ZONE GENERATED ALWAYS AS (
        get_case_death_datetime(
            dod_start_date, dod_start_time, dod_start_tz
        )
    ) STORED
;
CREATE INDEX gather_case_match_key_1_idx ON public.gather_case (match_key_1, funeral_home_id);
CREATE INDEX gather_case_match_key_2_idx ON public.gather_case (match_key_2, funeral_home_id);
CREATE INDEX gather_case_match_key_3_idx ON public.gather_case (match_key_3, funeral_home_id);
CREATE INDEX gather_case_match_key_4_idx ON public.gather_case (match_key_4, funeral_home_id);
CREATE INDEX gather_case_dod_datetime_idx ON public.gather_case (dod_datetime);


CREATE FUNCTION set_case_task_step_counts (_funeral_home_case_id INTEGER)
    RETURNS TABLE (
        funeral_home_case_id     INTEGER,
        uuid                     UUID,
        task_total_count         INTEGER,
        task_completed_count     INTEGER,
        step_total_count         INTEGER,
        step_completed_count     INTEGER
    )
AS $$
BEGIN

    -- Calculate the total & completed tasks and steps for this case
    WITH task_counts AS (
        SELECT
            COUNT(ct.funeral_home_case_id)::INTEGER AS total,
            SUM(CASE WHEN ct.marked_complete_time IS NOT NULL THEN 1 ELSE 0 END)::INTEGER AS completed
        FROM public.case_task AS ct
        JOIN public.task
            ON task.id = ct.task_id
        WHERE ct.funeral_home_case_id = _funeral_home_case_id
            -- exclude skipped tasks
            AND (ct.marked_complete_time IS NOT NULL OR ct.skipped_time IS NULL)
            AND task.deleted_time IS NULL
            AND task.type = 'checklist_task'
    ), step_counts AS (
        SELECT
            COUNT(ct.funeral_home_case_id)::INTEGER AS total,
            SUM(CASE WHEN ct.marked_complete_time IS NOT NULL THEN 1 ELSE 0 END)::INTEGER AS completed
        FROM public.case_task AS ct
        JOIN public.task
            ON task.id = ct.task_id
        WHERE ct.funeral_home_case_id = _funeral_home_case_id
            -- exclude skipped steps
            AND (ct.marked_complete_time IS NOT NULL OR ct.skipped_time IS NULL)
            AND task.deleted_time IS NULL
            AND task.type = 'tracking_step'
            AND task.tracking_step_type != 'move'
    )
    -- Update the case
    UPDATE public.funeral_home_case SET
        task_total_count = COALESCE(task_counts.total, 0),
        task_completed_count = COALESCE(task_counts.completed, 0),
        step_total_count = COALESCE(step_counts.total, 0),
        step_completed_count = COALESCE(step_counts.completed, 0)
    FROM task_counts
    CROSS JOIN step_counts
    WHERE funeral_home_case.id = _funeral_home_case_id;

    -- Return the results as a table
    RETURN QUERY SELECT
        fh_case.id AS funeral_home_case_id,
        fh_case.uuid,
        fh_case.task_total_count,
        fh_case.task_completed_count,
        fh_case.step_total_count,
        fh_case.step_completed_count
    FROM public.funeral_home_case AS fh_case
    WHERE fh_case.id = _funeral_home_case_id;

END; $$
LANGUAGE PLPGSQL;

-- LEDGER GRANTS
GRANT USAGE ON SCHEMA ledger_staging TO gatherapi;
GRANT USAGE ON SCHEMA ledger TO gatherapi;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ledger_staging TO gatherapi;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ledger TO gatherapi;

-- API user can mess with the staging table to heart's content
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ledger_staging TO gatherapi;
-- API user may not delete or update the non-staging, commited ledger tables
GRANT SELECT ON ALL TABLES IN SCHEMA ledger TO gatherapi;
-- Exception: API user can mark a posting as cleared
GRANT UPDATE ( cleared, cleared_by ) ON TABLE ledger.posting TO gatherapi;

-- PRODUCT GRANTS
GRANT USAGE ON SCHEMA product TO gatherapi;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA product TO gatherapi;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA product TO gatherapi;
alter default privileges in schema product grant SELECT, INSERT, UPDATE, DELETE on tables to gatherapi;

-- DATALOAD GRANTS
GRANT USAGE ON SCHEMA dataload TO gatherapi;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA dataload TO gatherapi;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA dataload TO gatherapi;
alter default privileges in schema dataload grant SELECT, INSERT, UPDATE, DELETE on tables to gatherapi;

-- BOOK GRANTS
GRANT USAGE ON SCHEMA book TO gatherapi;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA book TO gatherapi;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA book TO gatherapi;
alter default privileges in schema book grant SELECT, INSERT, UPDATE, DELETE on tables to gatherapi;

-- PUBLIC GRANTS
grant select, insert, update, delete on all tables in schema public to gatherapi;
grant usage, select, update on all sequences in schema public to gatherapi;
alter default privileges in schema public grant SELECT, INSERT, UPDATE, DELETE on tables to gatherapi;

-- Revoke permissions to UPDATE for the API user
-- All updates on email
-- REVOKE UPDATE ON TABLE user_profile FROM gatherapi;
-- GRANT UPDATE (select  column_name  from information_schema.columns where table_name = 'user_profile' and column_name not in ('email','phone') ) ON TABLE user_profile TO gatherapi;
-- REVOKE UPDATE (email, phone) ON TABLE user_profile FROM gatherapi;
