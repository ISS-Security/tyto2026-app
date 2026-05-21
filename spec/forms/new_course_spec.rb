# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Tyto::Form::NewCourse' do
  it 'HAPPY: name only' do
    _(Tyto::Form::NewCourse.call(name: 'Intro').success?).must_equal true
  end

  it 'HAPPY: name + description' do
    result = Tyto::Form::NewCourse.call(name: 'Intro', description: 'About things')
    _(result.success?).must_equal true
  end

  it 'SAD: empty name' do
    _(Tyto::Form::NewCourse.call(name: '').failure?).must_equal true
  end

  it 'SAD: name over 200 chars' do
    _(Tyto::Form::NewCourse.call(name: 'x' * 201).failure?).must_equal true
  end
end
