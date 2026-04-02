CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  wallet_address VARCHAR(128) UNIQUE,
  embedded_wallet_address VARCHAR(128),
  email VARCHAR(255) UNIQUE,
  phone VARCHAR(32),
  password_hash VARCHAR(255),
  role VARCHAR(32) NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'tutor', 'admin', 'arbitrator')),
  display_name VARCHAR(100) NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  locale VARCHAR(32) NOT NULL DEFAULT 'zh-CN',
  timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Shanghai',
  status VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending', 'banned')),
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE user_auth_identities (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  provider VARCHAR(50) NOT NULL,
  provider_user_id VARCHAR(255) NOT NULL,
  provider_email VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider, provider_user_id)
);

CREATE TABLE auth_email_codes (
  id BIGSERIAL PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  scene VARCHAR(32) NOT NULL,
  code_hash VARCHAR(255) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE wallet_login_challenges (
  id BIGSERIAL PRIMARY KEY,
  wallet_address VARCHAR(128) NOT NULL,
  nonce VARCHAR(128) NOT NULL UNIQUE,
  challenge_message TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE subjects (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  slug VARCHAR(100) NOT NULL UNIQUE,
  parent_id BIGINT REFERENCES subjects(id),
  sort_order INTEGER NOT NULL DEFAULT 0,
  status VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tutor_profiles (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id),
  headline VARCHAR(255),
  introduction TEXT,
  teaching_modes VARCHAR(100) NOT NULL DEFAULT 'online',
  hourly_rate NUMERIC(18, 6) NOT NULL DEFAULT 0,
  currency VARCHAR(16) NOT NULL DEFAULT 'USDC',
  years_of_experience INTEGER NOT NULL DEFAULT 0,
  verification_status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected', 'suspended')),
  is_listed BOOLEAN NOT NULL DEFAULT FALSE,
  average_rating NUMERIC(3, 2) NOT NULL DEFAULT 0,
  total_reviews INTEGER NOT NULL DEFAULT 0,
  completed_lessons INTEGER NOT NULL DEFAULT 0,
  repeat_purchase_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
  cancellation_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
  dispute_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tutor_subjects (
  id BIGSERIAL PRIMARY KEY,
  tutor_profile_id BIGINT NOT NULL REFERENCES tutor_profiles(id),
  subject_id BIGINT NOT NULL REFERENCES subjects(id),
  proficiency_level VARCHAR(32),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tutor_profile_id, subject_id)
);

CREATE TABLE tutor_languages (
  id BIGSERIAL PRIMARY KEY,
  tutor_profile_id BIGINT NOT NULL REFERENCES tutor_profiles(id),
  language_code VARCHAR(16) NOT NULL,
  proficiency VARCHAR(32),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tutor_profile_id, language_code)
);

CREATE TABLE tutor_availabilities (
  id BIGSERIAL PRIMARY KEY,
  tutor_profile_id BIGINT NOT NULL REFERENCES tutor_profiles(id),
  weekday SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  timezone VARCHAR(64) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tutor_credentials (
  id BIGSERIAL PRIMARY KEY,
  tutor_profile_id BIGINT NOT NULL REFERENCES tutor_profiles(id),
  credential_type VARCHAR(50) NOT NULL CHECK (credential_type IN ('degree', 'certificate', 'score_report', 'other')),
  title VARCHAR(255) NOT NULL,
  issuer VARCHAR(255),
  file_url TEXT,
  file_cid TEXT,
  verification_status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
  verified_by BIGINT REFERENCES users(id),
  verified_at TIMESTAMPTZ,
  remark TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tutor_verifications (
  id BIGSERIAL PRIMARY KEY,
  tutor_profile_id BIGINT NOT NULL REFERENCES tutor_profiles(id),
  action VARCHAR(32) NOT NULL,
  status VARCHAR(32) NOT NULL,
  operator_id BIGINT REFERENCES users(id),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE lesson_products (
  id BIGSERIAL PRIMARY KEY,
  tutor_profile_id BIGINT NOT NULL REFERENCES tutor_profiles(id),
  subject_id BIGINT REFERENCES subjects(id),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  price NUMERIC(18, 6) NOT NULL CHECK (price >= 0),
  currency VARCHAR(16) NOT NULL DEFAULT 'USDC',
  lesson_type VARCHAR(32) NOT NULL DEFAULT 'one_on_one',
  delivery_mode VARCHAR(32) NOT NULL DEFAULT 'online',
  status VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,
  order_no VARCHAR(64) NOT NULL UNIQUE,
  student_user_id BIGINT NOT NULL REFERENCES users(id),
  tutor_user_id BIGINT NOT NULL REFERENCES users(id),
  lesson_product_id BIGINT REFERENCES lesson_products(id),
  subject_id BIGINT REFERENCES subjects(id),
  order_title VARCHAR(255) NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  unit_price NUMERIC(18, 6) NOT NULL CHECK (unit_price >= 0),
  total_amount NUMERIC(18, 6) NOT NULL CHECK (total_amount >= 0),
  platform_fee NUMERIC(18, 6) NOT NULL DEFAULT 0 CHECK (platform_fee >= 0),
  currency VARCHAR(16) NOT NULL DEFAULT 'USDC',
  status VARCHAR(32) NOT NULL DEFAULT 'pending_payment'
    CHECK (status IN ('pending_payment', 'escrowed', 'scheduled', 'tutor_marked_complete', 'completed', 'disputed', 'refunded', 'cancelled')),
  scheduled_start_at TIMESTAMPTZ,
  scheduled_end_at TIMESTAMPTZ,
  complete_confirm_deadline TIMESTAMPTZ,
  chain_id BIGINT,
  chain_order_id VARCHAR(128),
  escrow_contract_address VARCHAR(128),
  tx_payment_hash VARCHAR(128),
  tx_release_hash VARCHAR(128),
  tx_refund_hash VARCHAR(128),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_status_logs (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  from_status VARCHAR(32),
  to_status VARCHAR(32) NOT NULL,
  actor_user_id BIGINT REFERENCES users(id),
  action VARCHAR(64),
  remark TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payments (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  payer_user_id BIGINT NOT NULL REFERENCES users(id),
  payee_user_id BIGINT REFERENCES users(id),
  payment_type VARCHAR(32) NOT NULL CHECK (payment_type IN ('pay', 'release', 'refund', 'fee')),
  amount NUMERIC(18, 6) NOT NULL CHECK (amount >= 0),
  currency VARCHAR(16) NOT NULL DEFAULT 'USDC',
  status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'failed')),
  chain_id BIGINT,
  token_address VARCHAR(128),
  tx_hash VARCHAR(128),
  block_number BIGINT,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE reviews (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  from_user_id BIGINT NOT NULL REFERENCES users(id),
  to_user_id BIGINT NOT NULL REFERENCES users(id),
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  is_visible BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(order_id, from_user_id, to_user_id)
);

CREATE TABLE review_tags (
  id BIGSERIAL PRIMARY KEY,
  review_id BIGINT NOT NULL REFERENCES reviews(id),
  tag VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE disputes (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id),
  raised_by_user_id BIGINT NOT NULL REFERENCES users(id),
  against_user_id BIGINT REFERENCES users(id),
  reason_code VARCHAR(50) NOT NULL,
  description TEXT,
  status VARCHAR(32) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'waiting_evidence', 'resolved', 'closed')),
  resolution_type VARCHAR(32),
  resolution_amount NUMERIC(18, 6),
  resolver_user_id BIGINT REFERENCES users(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE dispute_evidences (
  id BIGSERIAL PRIMARY KEY,
  dispute_id BIGINT NOT NULL REFERENCES disputes(id),
  user_id BIGINT NOT NULL REFERENCES users(id),
  file_url TEXT,
  file_cid TEXT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  related_type VARCHAR(50),
  related_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

CREATE TABLE attestation_records (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id),
  tutor_profile_id BIGINT REFERENCES tutor_profiles(id),
  order_id BIGINT REFERENCES orders(id),
  attestation_type VARCHAR(50) NOT NULL,
  schema_uid VARCHAR(128),
  attestation_uid VARCHAR(128),
  chain_id BIGINT,
  tx_hash VARCHAR(128),
  status VARCHAR(32) NOT NULL DEFAULT 'issued',
  metadata_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE admin_operation_logs (
  id BIGSERIAL PRIMARY KEY,
  operator_user_id BIGINT REFERENCES users(id),
  module VARCHAR(50) NOT NULL,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(50),
  target_id BIGINT,
  detail JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE chain_event_receipts (
  id BIGSERIAL PRIMARY KEY,
  chain_id BIGINT NOT NULL,
  contract_address VARCHAR(128) NOT NULL,
  tx_hash VARCHAR(128) NOT NULL,
  log_index INTEGER NOT NULL,
  event_name VARCHAR(100) NOT NULL,
  order_id BIGINT REFERENCES orders(id),
  payload JSONB NOT NULL,
  confirmed_block_number BIGINT,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tx_hash, log_index)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_wallet_address ON users(wallet_address);
CREATE INDEX idx_subjects_parent_id ON subjects(parent_id);
CREATE INDEX idx_tutor_profiles_verification_listed ON tutor_profiles(verification_status, is_listed);
CREATE INDEX idx_lesson_products_tutor_status ON lesson_products(tutor_profile_id, status);
CREATE INDEX idx_orders_student_status ON orders(student_user_id, status);
CREATE INDEX idx_orders_tutor_status ON orders(tutor_user_id, status);
CREATE INDEX idx_orders_order_no ON orders(order_no);
CREATE INDEX idx_payments_tx_hash ON payments(tx_hash);
CREATE INDEX idx_reviews_to_user_id ON reviews(to_user_id);
CREATE INDEX idx_disputes_status ON disputes(status);
CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX idx_chain_event_receipts_order_id ON chain_event_receipts(order_id);

CREATE TRIGGER trg_subjects_updated_at
BEFORE UPDATE ON subjects
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tutor_profiles_updated_at
BEFORE UPDATE ON tutor_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tutor_availabilities_updated_at
BEFORE UPDATE ON tutor_availabilities
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tutor_credentials_updated_at
BEFORE UPDATE ON tutor_credentials
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_lesson_products_updated_at
BEFORE UPDATE ON lesson_products
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_payments_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_reviews_updated_at
BEFORE UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_disputes_updated_at
BEFORE UPDATE ON disputes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
