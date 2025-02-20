# frozen_string_literal: true

#
# Copyright (C) 2014 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require 'spec_helper'
require 'zip'

FIXTURES_PATH = File.dirname(__FILE__) + '/fixtures'

def fixture_filename(fixture)
  File.join(FIXTURES_PATH, fixture)
end

describe "CanvasUnzip" do
  shared_examples_for 'it extracts archives with extension' do |extension|
    it "extracts an archive" do
      Dir.mktmpdir do |tmpdir|
        warnings = CanvasUnzip.extract_archive(fixture_filename("test.#{extension}"), tmpdir)
        expect(warnings).to eq({})
        expect(File.directory?(File.join(tmpdir, 'empty_dir'))).to be true
        expect(File.read(File.join(tmpdir, 'file1.txt'))).to eq "file1\n"
        expect(File.read(File.join(tmpdir, 'sub_dir/file2.txt'))).to eq "file2\n"
        expect(File.read(File.join(tmpdir, 'implicit_dir/file3.txt'))).to eq "file3\n"
      end
    end

    it "skips files that already exist by default" do
      Dir.mktmpdir do |tmpdir|
        File.open(File.join(tmpdir, 'file1.txt'), 'w') { |f| f.puts "OOGA" }
        warnings = CanvasUnzip.extract_archive(fixture_filename("test.#{extension}"), tmpdir)
        expect(warnings).to eq({ already_exists: ['file1.txt'] })
        expect(File.read(File.join(tmpdir, 'file1.txt'))).to eq "OOGA\n"
        expect(File.read(File.join(tmpdir, 'sub_dir/file2.txt'))).to eq "file2\n"
      end
    end

    it "skips unsafe entries" do
      Dir.mktmpdir do |tmpdir|
        subdir = File.join(tmpdir, 'sub_dir')
        Dir.mkdir(subdir)
        warnings = CanvasUnzip.extract_archive(fixture_filename("evil.#{extension}"), subdir)
        expect(warnings[:unsafe].sort).to eq ["../outside.txt", "evil_symlink", "tricky/../../outside.txt"]
        expect(File.exist?(File.join(tmpdir, 'outside.txt'))).to be false
        expect(File.exist?(File.join(subdir, 'evil_symlink'))).to be false
        expect(File.exist?(File.join(subdir, 'inside.txt'))).to be true
      end
    end

    it "deals with empty archives" do
      Dir.mktmpdir do |tmpdir|
        subdir = File.join(tmpdir, 'sub_dir')
        Dir.mkdir(subdir)
        expect { CanvasUnzip.extract_archive(fixture_filename("empty.#{extension}"), subdir) }.not_to raise_error
      end
    end

    it "enumerates entries" do
      indices = []
      entries = []
      warnings = CanvasUnzip.extract_archive(fixture_filename("evil.#{extension}")) do |entry, index|
        entries << entry
        indices << index
      end
      expect(warnings[:unsafe].sort).to eq ["../outside.txt", "evil_symlink", "tricky/../../outside.txt"]
      expect(indices.uniq.sort).to eq(indices)
      expect(entries.map(&:name)).to eq(['inside.txt', 'tricky/', 'tricky/innocuous_file'])
    end
  end

  describe "Limits" do
    it "computes reasonable default limits" do
      expect(CanvasUnzip.default_limits(100).maximum_bytes).to eq 10_000
      expect(CanvasUnzip.default_limits(1_000_000_000).maximum_bytes).to eq CanvasUnzip::DEFAULT_BYTE_LIMIT
    end

    it "raises an error if the file limit is exceeded" do
      expect do
        limits = CanvasUnzip::Limits.new(CanvasUnzip::DEFAULT_BYTE_LIMIT, 2)
        Dir.mktmpdir do |tmpdir|
          CanvasUnzip.extract_archive(fixture_filename("test.zip"), tmpdir, limits: limits)
        end
      end.to raise_error(CanvasUnzip::FileLimitExceeded)
    end

    it "raises an error if the byte limit is exceeded" do
      expect do
        limits = CanvasUnzip::Limits.new(10, 100)
        Dir.mktmpdir do |tmpdir|
          CanvasUnzip.extract_archive(fixture_filename("test.zip"), tmpdir, limits: limits)
        end
      end.to raise_error(CanvasUnzip::SizeLimitExceeded)
    end
  end

  describe "non-UTF-8 filenames" do
    it "converts zip filename entries from cp437 to utf-8" do
      stupid_entry = Zip::Entry.new
      stupid_entry.name = "mol\x82"
      expect(CanvasUnzip::Entry.new(stupid_entry).name).to eq('molé')
    end
  end

  describe '.compute_uncompressed_size' do
    it "uses the sum of sizes inside the archive" do
      filename = fixture_filename("bigcompression.zip")
      uncompressed_size = CanvasUnzip.compute_uncompressed_size(filename)
      expect(uncompressed_size > File.new(filename).size).to be_truthy
    end
  end

  it_behaves_like 'it extracts archives with extension', 'zip'
  it_behaves_like 'it extracts archives with extension', 'tar'
  it_behaves_like 'it extracts archives with extension', 'tar.gz'
end
