require_relative "test_helper"

class ModelTest < Minitest::Test
  def setup
    User.delete_all
  end

  def teardown
    # very important!!
    # ensure no plaintext attributes exist
    Lockbox.disable_protected_mode
    assert_no_plaintext_attributes if mongoid?
  end

  def create_user
    @name = "name"
    @email = "test@example.org"
    User.create!(email: email, name: @name)
    Lockbox.enable_protected_mode
  end

  def test_access_protected_mode
    email = "test@example.org"
    user = User.create!(email: email)
    Lockbox.enable_protected_mode
    refute_equal email, user.email
    assert_equal user.email_ciphertext, user.email
  end

  def test_decrypt_after_destroy
    email = "test@example.org"
    user = User.create!(email: email)
    Lockbox.enable_protected_mode
    user.destroy!

    refute_equal @email, user.email
    assert_equal user.email_ciphertext, user.email
  end

  def test_update_unencrypted_attribute
    email = "test@example.org"
    user = User.create!(email: email, name: "name")
    Lockbox.enable_protected_mode
    new_name = "othername"
    result = user.update(name: "othername")
    assert result
    assert_equal new_name, user.name
  end

  def test_update_encrypted_attribute
    email = "test@example.org"
    user = User.create!(email: email)
    Lockbox.enable_protected_mode
    new_email = "other@email.com"
    result = user.update(email: new_email)

    refute result
    refute_equal new_email, user.email
    refute_equal email, user.email
  end

  def test_update_with_error_encrypted_attribute
    email = "test@example.org"
    user = User.create!(email: email)
    Lockbox.enable_protected_mode
    new_email = "other@email.com"

    assert_raises(Lockbox::Error) do
      user.update!(email: new_email)
    end
  end

  def test_save_with_encrypted_attribute
    email = "test@example.org"
    user = User.create!(email: email)
    Lockbox.enable_protected_mode
    new_email = "other@email.com"
    user.email = new_email
    result = user.save

    refute result
    refute_equal new_email, user.email
    refute_equal email, user.email
  end

  def test_save_with_error_with_encrypted_attribute
    email = "test@example.org"
    user = User.create!(email: email)
    Lockbox.enable_protected_mode
    new_email = "other@email.com"
    user.email = new_email

    assert_raises(Lockbox::Error) do
      user.save!
    end
  end

  def test_update_columns_encrypted_attributes
    email = "test@example.org"
    user = User.create!(email: email)
    Lockbox.enable_protected_mode
    new_email = "otheremail@email.com"
    user.update_column(:email, new_email)

    Lockbox.disable_protected_mode
    assert_equal user.email, new_email
  end

  def test_changes
    email = "test@example.org"
    name = "name"
    user = User.create!(email: email, name: name)
    Lockbox.enable_protected_mode
    new_email = "otheremail@email.com"
    new_name = "othername"

    user.name = new_name
    user.email = new_email
    user_changes = user.changes

    refute_includes user_changes["email"], email, new_email
    assert_includes user_changes["name"], name, new_name
  end

  def test_create_method
    Lockbox.enable_protected_mode
    assert_raises(Lockbox::Error) do
      User.create!(name: "othertest", email: "other@email.com")
    end
  end

  def test_decrypt_method
    user = User.create!(email: "test@example.org")
    Lockbox.enable_protected_mode
    key = Lockbox.attribute_key(table: "users", attribute: "encrypted_email")
    box = Lockbox.new(key: key, encode: true)

    assert_equal user.email_ciphertext, box.decrypt(user.email_ciphertext)
    assert_equal user.email, box.decrypt(user.email_ciphertext)
  end

  def test_pluck_with_encrypted_attributes
    email = "test@example.org"
    other_email = "other@email.com"
    User.create!(email: email)
    User.create!(email: other_email)
    Lockbox.enable_protected_mode

    assert_equal User.pluck(:email).count, 2

    refute_includes User.pluck(:email), email, other_email
    assert_equal User.pluck(:email), User.pluck(:email_ciphertext)
  end

  def test_pluck_with_unencrypted_attributes
    name = "name"
    other_name = "othername"
    User.create!(name: name)
    User.create!(name: other_name)
    Lockbox.enable_protected_mode

    assert_equal User.pluck(:name).count, 2

    assert_includes User.pluck(:name), name, other_name
  end

  def test_pluck_with_multiple_attributes
    name = "name"
    other_name = "othername"
    user = User.create!(name: name, email: "test@example.org")
    user_2 = User.create!(name: other_name, email: "other@email.com")
    Lockbox.enable_protected_mode

    assert_equal User.pluck(:name, :email).count, 2

    assert_equal User.order(:id).pluck(:name, :email), [[user.name, user.email_ciphertext], [other_name, user_2.email_ciphertext]]
  end
end
