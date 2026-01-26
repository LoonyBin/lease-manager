require 'rails_helper'

RSpec.describe Property, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      property = build(:property)
      expect(property).to be_valid
    end

    it 'is invalid without a name' do
      property = build(:property, name: nil)
      expect(property).not_to be_valid
      expect(property.errors[:name]).to include("can't be blank")
    end

    it 'is invalid without an address' do
      property = build(:property, address: nil)
      expect(property).not_to be_valid
      expect(property.errors[:address]).to include("can't be blank")
    end
  end
end
