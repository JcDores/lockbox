require_relative "test_helper"

class ModelTest < Minitest::Test
  def setup
    User.delete_all
    @name = 'name'
    @email = "test@example.org"
    User.create!(email: @email, name: @name)
    Lockbox.enable_protected_mode
  end

  def teardown
    # very important!!
    # ensure no plaintext attributes exist
    assert_no_plaintext_attributes if mongoid?
    Lockbox.disable_protected_mode
  end

  def test_access_protected_mode
    user = User.last
    refute_equal @email, user.email
    assert_equal user.email_ciphertext, user.email
  end

  def test_decrypt_after_destroy
    user = User.last
    user.destroy!

    refute_equal @email, user.email
    assert_equal user.email_ciphertext, user.email
  end

  def test_update_unencrypted_attribute
    user = User.last
    new_name = 'othername'
    result = user.update(name: 'othername')
    assert result
    assert_equal new_name, user.name
  end

  def test_update_encrypted_attribute
    user = User.last
    new_email = 'other@email.com'
    result = user.update(email: new_email)

    refute result
    refute_equal new_email, user.email
    refute_equal @email, user.email
  end

  def test_update_with_error_encrypted_attribute
    user = User.last
    new_email = 'other@email.com'

    assert_raises(Lockbox::Error) do
      user.update!(email: new_email)
    end
  end

  def test_save_with_encrypted_attribute
    new_email = 'other@email.com'
    user = User.last
    user.email = new_email
    result = user.save

    refute result
    refute_equal new_email, user.email
    refute_equal @email, user.email
  end

  def test_save_with_error_with_encrypted_attribute
    new_email = 'other@email.com'
    user = User.last
    user.email = new_email

    assert_raises(Lockbox::Error) do
      user.save!
    end
  end

  def test_update_columns_encrypted_attributes
    new_email = 'otheremail@email.com'
    user = User.last
    user.update_column(:email, new_email)

    Lockbox.disable_protected_mode
    assert_equal user.email, new_email
  end

  def test_changes
    new_email = 'otheremail@email.com'
    new_name = 'othername'
    user = User.last
    user.name = new_name
    user.email = new_email

    user_changes = user.changes

    refute_includes user_changes, @email, new_email
    assert_includes user_changes, @name, new_name
  end

  def test_create_method
    assert_raises(Lockbox::Error) do
      User.create!(name: 'othertest', email: 'other@email.com')
    end
  end

  def test_decrypt_method
    key = Lockbox.attribute_key(table: "users", attribute: "encrypted_email")
    box = Lockbox.new(key: key, encode: true)
    user = User.last

    assert_equal user.email_ciphertext, box.decrypt(user.email_ciphertext)
    assert_equal user.email, box.decrypt(user.email_ciphertext)
  end

  def test_pluck_with_encrypted_attributes
    other_email = 'other@email.com'
    Lockbox.disable_protected_mode
    User.create!(name: 'othertest', email: other_email)
    Lockbox.enable_protected_mode

    assert_equal User.pluck(:email).count, 2

    refute_includes User.pluck(:email), @email, other_email
    assert_equal User.pluck(:email), User.pluck(:email_ciphertext)
  end

  def test_pluck_with_unencrypted_attributes
    other_name = 'othername'
    other_email = 'other@email.com'
    Lockbox.disable_protected_mode
    User.create!(name: other_name, email: other_email)
    Lockbox.enable_protected_mode

    assert_equal User.pluck(:name).count, 2

    assert_includes User.pluck(:name), @name, other_name
  end

  def test_pluck_with_multiple_attributes
    other_name = 'othername'
    other_email = 'other@email.com'
    Lockbox.disable_protected_mode
    User.create!(name: other_name, email: other_email)
    Lockbox.enable_protected_mode

    assert_equal User.pluck(:name, :email).count, 2

    assert_includes User.pluck(:name), [[@name, @email], [other_name, other_email]]
  end
end
