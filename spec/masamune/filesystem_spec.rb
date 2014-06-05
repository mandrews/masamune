require 'spec_helper'

require 'securerandom'

# NOTE when operating between hdfs and s3, hadoop fs requires s3n URI
# See: http://wiki.apache.org/hadoop/AmazonS3
shared_examples_for 'Filesystem' do
  let(:filesystem) { Masamune::Filesystem.new }

  let(:tmp_dir) { File.join(Dir.tmpdir, SecureRandom.hex) }
  let(:old_dir) { File.join(tmp_dir, SecureRandom.hex) }
  let(:new_dir) { File.join(tmp_dir, SecureRandom.hex) }
  let(:other_new_dir) { File.join(tmp_dir, SecureRandom.hex) }
  let(:new_file) { File.join(old_dir, SecureRandom.hex) }
  let(:other_new_file) { File.join(old_dir, SecureRandom.hex) }
  let!(:old_file) {
    FileUtils.mkdir_p(old_dir)
    File.join(old_dir, SecureRandom.hex + '.txt').tap do |file|
      FileUtils.touch file
    end
  }

  before do
    filesystem.configuration.retries = 0
    FileUtils.mkdir_p(old_dir)
  end

  after do
    FileUtils.rmdir(tmp_dir)
  end

  describe '#get_path' do
    context 'after add_path is called' do
      before do
        instance.add_path(:home_dir, '/home')
      end
      it { instance.get_path(:home_dir).should == '/home' }

      context 'with extra directories' do
        it { instance.get_path(:home_dir, 'a', 'b', 'c').should == '/home/a/b/c' }
      end

      context 'with extra directories delimited by "/"' do
        it { instance.get_path(:home_dir, '/a/b', 'c').should == '/home/a/b/c' }
      end

      context 'with parameter substitution' do
        before do
          instance.configuration.params[:user] = 'zombo'
          instance.add_path(:user_path, '/home/%user/files')
        end
        it { instance.get_path(:user_path).should == '/home/zombo/files' }

        context 'in extra section' do
          before do
            instance.configuration.params[:file] = 'anything_is_possible.txt'
          end
          it { instance.get_path(:user_path, '%file').should == '/home/zombo/files/anything_is_possible.txt' }
        end
      end
    end

    context 'before add_path is called' do
      it { instance.get_path(:home_dir).should be_a(Proc) }
    end
  end

  describe '#parent_paths' do
    subject { instance.parent_paths(path) }

    context 'with local blank' do
      let(:path) { '' }
      it { should == [] }
    end

    context 'with local path with slash' do
      let(:path) { '/a/b/c' }
      it { should == ['/', '/a', '/a/b'] }
    end

    context 'with local path without slash' do
      let(:path) { 'a/b/c' }
      it { should == ['a', 'a/b'] }
    end

    context 'with s3 bucket with blank' do
      let(:path) { 's3://bucket' }
      it { should == [] }
    end

    context 'with s3 bucket with slash' do
      let(:path) { 's3://bucket/' }
      it { should == [] }
    end

    context 'with s3 bucket with path' do
      let(:path) { 's3://bucket/a/b/c' }
      it { should == ['s3://bucket/', 's3://bucket/a', 's3://bucket/a/b'] }
    end

    context 'with hdfs directory with path' do
      let(:path) { 'hdfs:///a/b/c' }
      it { should == ['hdfs:///', 'hdfs:///a', 'hdfs:///a/b'] }
    end
  end

  describe '#root_path?' do
    subject { instance.root_path?(path) }

    context 'with nil' do
      let(:path) { nil }
      it { expect { |b| subject }.to raise_error ArgumentError }
    end

    context 'with blank' do
      let(:path) { ' ' }
      it { expect { |b| subject }.to raise_error ArgumentError }
    end

    context 'with local root' do
      let(:path) { '/' }
      it { should be_true }
    end

    context 'with local non-root' do
      let(:path) { '/tmp' }
      it { should be_false }
    end

    context 'with hdfs root' do
      let(:path) { 'file:///' }
      it { should be_true }
    end

    context 'with hdfs non-root' do
      let(:path) { 'file:///tmp' }
      it { should be_false }
    end

    context 'with s3 root' do
      let(:path) { 's3://bucket/' }
      it { should be_true }
    end

    context 'with s3 non-root' do
      let(:path) { 's3://bucket/tmp' }
      it { should be_false }
    end

    context 'with s3 bucket' do
      let(:path) { 's3://bucket' }
      it { should be_true }
    end
  end

  describe '#resolve_file' do
    subject { instance.resolve_file(paths) }

    context 'with nil' do
      let(:paths) { nil }
      it { should be_nil }
    end

    context 'with empty' do
      let(:paths) { [] }
      it { should be_nil }
    end

    context 'with one file' do
      let(:paths) { old_file }
      it { should == old_file }
    end

    context 'with directories and file' do
      let(:paths) { [old_dir, new_dir, new_file, old_file] }
      it { should == old_file }
    end
  end

  describe '#dirname' do
    subject { instance.dirname(path) }

    context 'with local blank' do
      let(:path) { '' }
      it { should be_blank }
    end

    context 'with local path with slash' do
      let(:path) { '/a/b/c' }
      it { should == '/a/b' }
    end

    context 'with local path without slash' do
      let(:path) { 'a/b/c' }
      it { should == 'a/b' }
    end

    context 'with local relative path' do
      let(:path) { '/a/b/../c' }
      it { should == '/a/c' }
    end

    context 'with s3 bucket with blank' do
      let(:path) { 's3://bucket' }
      it { should == 's3://bucket' }
    end

    context 'with s3 bucket with slash' do
      let(:path) { 's3://bucket/' }
      it { should == 's3://bucket/' }
    end

    context 'with s3 bucket with path' do
      let(:path) { 's3://bucket/a/b/c' }
      it { should == 's3://bucket/a/b' }
    end

    context 'with s3 bucket with relative path' do
      let(:path) { 's3://bucket/a/b/../c' }
      it { should == 's3://bucket/a/c' }
    end

    context 'with hdfs directory with path' do
      let(:path) { 'hdfs:///a/b/c' }
      it { should == 'hdfs:///a/b' }
    end

    context 'with hdfs directory with path' do
      let(:path) { 'hdfs:///a/b/c' }
      it { should == 'hdfs:///a/b' }
    end

    context 'with hdfs directory with relative path' do
      let(:path) { 'hdfs:///a/b/../c' }
      it { should == 'hdfs:///a/c' }
    end
  end

  describe '#basename' do
    subject { instance.basename(path) }

    context 'with local blank' do
      let(:path) { '' }
      it { should be_blank }
    end

    context 'with local path with slash' do
      let(:path) { '/a/b/c' }
      it { should == 'c' }
    end

    context 'with local path without slash' do
      let(:path) { 'a/b/c' }
      it { should == 'c' }
    end

    context 'with local relative path' do
      let(:path) { '/a/b/../c' }
      it { should == 'c' }
    end

    context 'with s3 bucket with blank' do
      let(:path) { 's3://bucket' }
      it { should be_nil }
    end

    context 'with s3 bucket with slash' do
      let(:path) { 's3://bucket/' }
      it { should be_nil }
    end

    context 'with s3 bucket with path' do
      let(:path) { 's3://bucket/a/b/c' }
      it { should == 'c' }
    end

    context 'with s3 bucket with relative path' do
      let(:path) { 's3://bucket/a/b/../c' }
      it { should == 'c' }
    end

    context 'with hdfs directory with path' do
      let(:path) { 'hdfs:///a/b/c' }
      it { should == 'c' }
    end

    context 'with hdfs directory with path' do
      let(:path) { 'hdfs:///a/b/c' }
      it { should == 'c' }
    end

    context 'with hdfs directory with relative path' do
      let(:path) { 'hdfs:///a/b/../c' }
      it { should == 'c' }
    end
  end

  describe '#touch!' do
    subject do
      File.exists?(new_file) && File.exists?(other_new_file)
    end

    context 'local' do
      before do
        instance.touch!(new_file, other_new_file)
      end
      it { should be_true }
    end

    context 'hdfs' do
      before do
        instance.touch!('file://' + new_file, 'file://' + other_new_file)
      end
      it { should be_true }
    end

    context 's3' do
      before do
        filesystem.should_receive(:s3cmd).with('put', an_instance_of(String), 's3://bucket/file').at_most(:once)
        filesystem.should_receive(:s3cmd).with('put', an_instance_of(String), 's3://bucket/other_file').at_most(:once)
        instance.touch!('s3://bucket/file', 's3://bucket/other_file')
      end

      it 'meets expectations' do; end
    end
  end

  describe '#exists?' do
    context 'local missing file' do
      subject { instance.exists?(new_file) }
      it { should be_false }
    end

    context 'hdfs missing file' do
      subject { instance.exists?('file://' + new_file) }
      it { should be_false }
    end

    context 'local existing file' do
      subject { instance.exists?(old_file) }
      it { should be_true }
    end

    context 'hdfs existing file' do
      subject { instance.exists?('file://' + old_file) }
      it { should be_true }
    end
  end

  describe '#stat' do
    subject { result.last }
    context 'local missing file' do
      let(:result) { instance.stat(new_file) }
      it { should be_nil }
    end

    context 'hdfs missing file' do
      let(:result) { instance.stat('file://' + new_file) }
      it { should be_nil }
    end

    context 's3 missing file' do
      before do
        filesystem.should_receive(:s3cmd).with('ls', 's3://bucket/', safe: true).at_most(:once)
        filesystem.should_receive(:s3cmd).with('ls', '--recursive', %r{s3://bucket/[\*|file.txt]}, safe: true).
          and_yield('')
      end
      let(:result) { instance.stat('s3://bucket/file.txt') }
      it { should be_nil }
    end

    context 'local existing file' do
      let(:result) { instance.stat(old_file) }
      its(:name) { should == old_file }
      its(:mtime) { should == File.stat(old_file).mtime.at_beginning_of_minute.utc }
      its(:mtime) { should be_a(Time) }
      its(:size) { should be_an(Integer) }
    end

    context 'local existing file (recursive)' do
      let(:result) { instance.stat(File.join(tmp_dir, '*')) }
      its(:name) { should == old_file }
      its(:mtime) { should == File.stat(old_file).mtime.at_beginning_of_minute.utc }
      its(:mtime) { should be_a(Time) }
      its(:size) { should be_an(Integer) }
    end

    context 'local existing file (with suffix)' do
      let(:result) { instance.stat(File.join(old_dir, '*.txt')) }
      its(:name) { should == old_file }
      its(:mtime) { should == File.stat(old_file).mtime.at_beginning_of_minute.utc }
      its(:mtime) { should be_a(Time) }
      its(:size) { should be_an(Integer) }
    end

    context 'hdfs existing file' do
      let(:result) { instance.stat('file://' + old_file) }
      its(:name) { should == 'file://' + old_file }
      its(:mtime) { should == File.stat(old_file).mtime.at_beginning_of_minute.utc }
      its(:mtime) { should be_a(Time) }
      its(:size) { should be_an(Integer) }
    end

    context 's3 existing file' do
      before do
        filesystem.should_receive(:s3cmd).with('ls', '--recursive', %r{s3://bucket/[\*|file.txt]}, safe: true).
          and_yield(%q(2013-05-24 18:52      2912   s3://bucket/file.txt))
      end
      let(:result) { instance.stat('s3://bucket/file.txt') }
      its(:name) { should == 's3://bucket/file.txt' }
      its(:mtime) { should == Time.parse('2013-05-24 18:52:00 +0000') }
      its(:mtime) { should be_a(Time) }
      its(:size) { should == 2912 }
    end
  end

  describe '#mkdir!' do
    subject do
      Dir.exists?(new_dir) && Dir.exists?(other_new_dir)
    end

    context 'local directory' do
      before do
        instance.mkdir!(new_dir, other_new_dir)
      end
      it { should be_true }
    end

    context 'hdfs directory' do
      before do
        instance.mkdir!('file://' + new_dir, 'file://' + other_new_dir)
      end
      it { should be_true }
    end

    context 's3 directory' do
      before do
        filesystem.should_receive(:s3cmd).with('put', an_instance_of(String), 's3://bucket/dir/.not_empty').at_most(:once)
        filesystem.should_receive(:s3cmd).with('put', an_instance_of(String), 's3://bucket/other_dir/.not_empty').at_most(:once)
        instance.mkdir!('s3://bucket/dir', 's3://bucket/other_dir')
      end

      it 'meets expectations' do; end
    end
  end

  describe '#glob' do
    subject do
      instance.glob(pattern)
    end

    context 'local no matches' do
      let(:pattern) { File.join(new_dir, '*') }
      it { should be_empty }
      it { expect { |b| instance.glob(pattern, &b) }.to_not yield_control }
    end

    context 'local one matches' do
      let(:pattern) { File.join(File.dirname(old_file), '*') }
      it { should_not be_empty }
      it { expect { |b| instance.glob(pattern, &b) }.to yield_with_args(old_file) }
    end

    context 'local one matches (recursive)' do
      let(:pattern) { File.join(tmp_dir, '*') }
      it { should have(2).items }
      it { should include old_dir }
      it { should include old_file }
      it { expect { |b| instance.glob(pattern, &b) }.to yield_successive_args(old_dir, old_file) }
    end

    context 'local one matches (with suffix)' do
      let(:pattern) { File.join(File.dirname(old_file), '*.txt') }
      it { should have(1).items }
      it { should include old_file }
      it { expect { |b| instance.glob(pattern, &b) }.to yield_with_args(old_file) }
    end

    context 'hdfs no matches' do
      let(:pattern) { File.join(new_dir, '*') }
      it { should be_empty }
      it { expect { |b| instance.glob('file://' + pattern, &b) }.to_not yield_control }
    end

    context 'hdfs one matches' do
      let(:pattern) { File.join(File.dirname(old_file), '*') }
      it { should_not be_empty }
      it { expect { |b| instance.glob('file://' + pattern, &b) }.to yield_with_args('file://' + old_file) }
    end

    context 's3 no matches' do
      let(:pattern) { 's3://bucket/dir/*.txt' }

      before do
        filesystem.should_receive(:s3cmd).with('ls', '--recursive', "s3://bucket/*", safe: true).at_most(:once)
        filesystem.should_receive(:s3cmd).with('ls', '--recursive', "s3://bucket/dir/*", safe: true).at_most(:once)
      end

      it { should be_empty }
    end

    context 's3 one matches' do
      let(:pattern) { 's3://bucket/dir/*.txt' }

      before do
        filesystem.should_receive(:s3cmd).with('ls', '--recursive', "s3://bucket/dir/*", safe: true).
          and_yield(%q(2013-05-24 18:52      2912   s3://bucket/dir/file.txt)).
          and_yield(%q(2013-05-24 18:53      2912   s3://bucket/dir/file.csv))
      end

      it { should include 's3://bucket/dir/file.txt' }
      it { should_not include 's3://bucket/dir/file.csv' }
    end

    context 's3 many matches' do
      let(:pattern) { 's3://bucket/dir/*' }

      before do
        filesystem.should_receive(:s3cmd).with('ls', '--recursive', "s3://bucket/dir/*", safe: true).
          and_yield(%q(                       DIR   s3://bucket/dir/file_$folder$)).
          and_yield(%q(2013-05-24 18:52      2912   s3://bucket/dir/file.txt)).
          and_yield(%q(2013-05-24 18:53      2912   s3://bucket/dir/file.csv))
      end

      it { should include 's3://bucket/dir/file.txt' }
      it { should include 's3://bucket/dir/file.csv' }
    end
  end

  describe '#glob_sort' do
    before do
      Masamune::Filesystem.any_instance.stub(:glob).and_return(%w(/tmp/a/02.txt /tmp/b/01.txt /tmp/c/00.txt))
    end

    subject do
      instance.glob_sort('/tmp/*', order: :basename)
    end

    it { should == %w(/tmp/c/00.txt /tmp/b/01.txt /tmp/a/02.txt) }
  end

  describe '#copy_file' do
    subject do
      File.exists?(File.join(new_dir, File.basename(old_file)))
    end

    context 'local file to local dir' do
      before do
        instance.copy_file(old_file, new_dir)
      end

      it { should be_true }
    end

    context 'local file to s3 dir' do
      before do
        filesystem.should_receive(:s3cmd).with('put', old_file, 's3://bucket/new_dir/')
        instance.copy_file(old_file, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 'local file to hdfs dir' do
      before do
        instance.copy_file(old_file, 'file://' + new_dir)
      end

      it { should be_true }
    end

    context 'hdfs file to hdfs dir' do
      before do
        instance.copy_file('file://' + old_file, 'file://' + new_dir)
      end

      it { should be_true }
    end

    context 'hdfs file to local dir' do
      before do
        instance.copy_file('file://' + old_file, new_dir)
      end

      it { should be_true }
    end

    context 'hdfs file to s3 dir' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-cp', 'file://' + old_file, 's3n://bucket/new_dir')
        instance.copy_file('file://' + old_file, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 file to s3 dir' do
      before do
        filesystem.should_receive(:s3cmd).with('cp', 's3://bucket/old_file', 's3://bucket/new_dir/')
        instance.copy_file('s3://bucket/old_file', 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 file to local dir' do
      before do
        filesystem.should_receive(:s3cmd).with('get', 's3://bucket/old_file', new_dir)
        instance.copy_file('s3://bucket/old_file', new_dir)
      end

      it 'meets expectations' do; end
    end

    context 's3 file to hdfs dir' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-mkdir', '-p', 'file://' + new_dir)
        filesystem.should_receive(:hadoop_fs).with('-cp', 's3n://bucket/old_file', 'file://' + new_dir)
        instance.copy_file('s3://bucket/old_file', 'file://' + new_dir)
      end

      it 'meets expectations' do; end
    end
  end

  describe '#copy_dir' do
    subject do
      File.exists?(File.join(new_dir, File.basename(old_dir), File.basename(old_file)))
    end

    context 'local dir to local dir' do
      before do
        instance.copy_dir(old_dir, new_dir)
      end

      it { should be_true }
    end

    context 'local dir to s3 dir' do
      before do
        filesystem.should_receive(:s3cmd).with('put', '--recursive', old_dir, 's3://bucket/new_dir/')
        instance.copy_dir(old_dir, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 'local dir to hdfs dir' do
      before do
        instance.copy_dir(old_dir, 'file://' + new_dir)
      end

      it { should be_true }
    end

    context 'hdfs dir to hdfs dir' do
      before do
        instance.copy_dir('file://' + old_dir, 'file://' + new_dir)
      end

      it { should be_true }
    end

    context 'hdfs dir to local dir' do
      before do
        instance.copy_dir('file://' + old_dir, new_dir)
      end

      it { should be_true }
    end

    context 'hdfs dir to s3 dir' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-cp', 'file://' + old_dir, 's3n://bucket/new_dir')
        instance.copy_dir('file://' + old_dir, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 dir to s3 dir' do
      before do
        filesystem.should_receive(:s3cmd).with('cp', '--recursive', 's3://bucket/old_dir/', 's3://bucket/new_dir/')
        instance.copy_dir('s3://bucket/old_dir', 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 dir to local dir' do
      before do
        filesystem.should_receive(:s3cmd).with('get', '--recursive', '--skip-existing', 's3://bucket/old_dir/', File.join(new_dir, 'old_dir'))
        instance.copy_dir('s3://bucket/old_dir', new_dir)
      end

      it 'meets expectations' do; end
    end

    context 's3 dir to hdfs dir' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-mkdir', '-p', 'file://' + new_dir)
        filesystem.should_receive(:hadoop_fs).with('-cp', 's3n://bucket/old_dir', 'file://' + new_dir)
        instance.copy_dir('s3://bucket/old_dir', 'file://' + new_dir)
      end

      it 'meets expectations' do; end
    end
  end

  describe '#remove_dir' do
    subject do
      File.exists?(old_dir)
    end

    context 'local dir' do
      before do
        instance.remove_dir(old_dir)
      end

      it { should be_false}
    end

    context 'hdfs dir' do
      before do
        instance.remove_dir('file://' + old_dir)
      end

      it { should be_false}
    end

    context 's3 dir' do
      before do
        filesystem.should_receive(:s3cmd).with('del', '--recursive', 's3://bucket/dir/')
        filesystem.should_receive(:s3cmd).with('del', '--recursive', 's3://bucket/dir_$folder$')
        instance.remove_dir('s3://bucket/dir')
      end

      it 'meets expectations' do; end
    end
  end

  describe '#move_file' do
    subject(:removes_old_file) do
      !File.exists?(old_file)
    end

    subject(:creates_new_file) do
      File.exists?(new_file)
    end

    context 'local file to local file' do
      before do
        FileUtils.should_receive(:chmod).once
        instance.move_file(old_file, new_file)
      end

      it { removes_old_file.should be_true }
      it { creates_new_file.should be_true }
    end

    context 'local file to s3 file' do
      before do
        filesystem.should_receive(:s3cmd).with('put', old_file, 's3://bucket/new_dir')
        instance.move_file(old_file, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
      it { removes_old_file.should be_true }
    end

    context 'local file to hdfs file' do
      before do
        instance.move_file(old_file, 'file://' + new_file)
      end

      it { removes_old_file.should be_true }
      it { creates_new_file.should be_true }
    end

    context 'hdfs file to hdfs file' do
      before do
        instance.move_file('file://' + old_file, 'file://' + new_file)
      end

      it { removes_old_file.should be_true }
      it { creates_new_file.should be_true }
    end

    context 'hdfs file to local file' do
      before do
        instance.move_file('file://' + old_file, new_file)
      end

      it { removes_old_file.should be_true }
      it { creates_new_file.should be_true }
    end

    context 'hdfs file to s3 file' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-cp', 'file://' + old_file, 's3n://bucket/new_dir')
        filesystem.should_receive(:hadoop_fs).with('-rm', 'file://' + old_file)
        instance.move_file('file://' + old_file, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 file to s3 file' do
      before do
        filesystem.should_receive(:s3cmd).with('mv', 's3://bucket/old_file', 's3://bucket/new_dir')
        instance.move_file('s3://bucket/old_file', 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 file to local file' do
      before do
        filesystem.should_receive(:s3cmd).with('get', 's3://bucket/old_file', new_dir)
        filesystem.should_receive(:s3cmd).with('del', 's3://bucket/old_file')
        instance.move_file('s3://bucket/old_file', new_dir)
      end

      it 'meets expectations' do; end
    end

    context 's3 file to hdfs file' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-mkdir', '-p', 'file://' + File.dirname(new_file))
        filesystem.should_receive(:hadoop_fs).with('-mv', 's3n://bucket/old_file', 'file://' + new_file)
        instance.move_file('s3://bucket/old_file', 'file://' + new_file)
      end

      it 'meets expectations' do; end
    end
  end

  describe '#move_dir' do
    subject(:removes_old_dir) do
      !File.exists?(old_dir)
    end

    subject(:creates_new_dir) do
      File.exists?(new_dir)
    end

    context 'local dir to local dir' do
      before do
        instance.move_dir(old_dir, new_dir)
      end

      it { removes_old_dir.should be_true }
      it { creates_new_dir.should be_true }
    end

    context 'local dir to s3 dir' do
      before do
        filesystem.should_receive(:s3cmd).with('put', '--recursive', old_dir + '/', 's3://bucket/new_dir/')
        instance.move_dir(old_dir, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
      it { removes_old_dir.should be_true }
    end

    context 'local dir to hdfs dir' do
      before do
        instance.move_dir(old_dir, 'file://' + new_dir)
      end

      it { removes_old_dir.should be_true }
      it { creates_new_dir.should be_true }
    end

    context 'hdfs dir to hdfs dir' do
      before do
        instance.move_dir('file://' + old_dir, 'file://' + new_dir)
      end

      it { removes_old_dir.should be_true }
      it { creates_new_dir.should be_true }
    end

    context 'hdfs dir to local dir' do
      before do
        instance.move_dir('file://' + old_dir, new_dir)
      end

      it { removes_old_dir.should be_true }
      it { creates_new_dir.should be_true }
    end

    context 'hdfs dir to s3 dir' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-cp', 'file://' + old_dir, 's3n://bucket/new_dir/')
        filesystem.should_receive(:hadoop_fs).with('-rmr', 'file://' + old_dir)
        instance.move_dir('file://' + old_dir, 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 dir to s3 dir' do
      before do
        filesystem.should_receive(:s3cmd).with('mv', '--recursive', 's3://bucket/old_dir/', 's3://bucket/new_dir')
        instance.move_dir('s3://bucket/old_dir', 's3://bucket/new_dir')
      end

      it 'meets expectations' do; end
    end

    context 's3 dir to local dir' do
      before do
        filesystem.should_receive(:s3cmd).with('get', '--recursive', 's3://bucket/old_dir/', new_dir)
        filesystem.should_receive(:s3cmd).with('del', '--recursive', 's3://bucket/old_dir/')
        filesystem.should_receive(:s3cmd).with('del', '--recursive', 's3://bucket/old_dir_$folder$')
        instance.move_dir('s3://bucket/old_dir', new_dir)
      end

      it 'meets expectations' do; end
    end

    context 's3 dir to hdfs dir' do
      before do
        filesystem.should_receive(:hadoop_fs).with('-mkdir', '-p', 'file://' + new_dir)
        filesystem.should_receive(:hadoop_fs).with('-cp', 's3n://bucket/old_dir', 'file://' + new_dir)
        filesystem.should_receive(:s3cmd).with('del', '--recursive', 's3://bucket/old_dir/')
        filesystem.should_receive(:s3cmd).with('del', '--recursive', 's3://bucket/old_dir_$folder$')
        instance.move_dir('s3://bucket/old_dir', 'file://' + new_dir)
      end

      it 'meets expectations' do; end
    end
  end

  context 'directory marked as immutable' do
    let(:dir) { 's3://bucket/incoming' }
    let(:file) { File.join(dir, '20130420.log') }

    before do
      instance.add_path(:incoming, dir, immutable: true)
    end

    describe '#remove_dir' do
      subject do
        instance.remove_dir(dir)
      end

      it { expect { subject }.to raise_error RuntimeError, /#{dir} is marked as immutable, cannot modify #{dir}/ }

      context 'nested directory' do
        let(:nested_dir) { File.join(dir, '2013') }

        subject do
          instance.remove_dir(nested_dir)
        end

        it { expect { subject }.to raise_error RuntimeError, /#{dir} is marked as immutable, cannot modify #{nested_dir}/ }
      end
    end

    describe '#move_file' do
      subject do
        instance.move_file(dir, 's3://bucket/processed/')
      end

      it { expect { subject }.to raise_error RuntimeError, /#{dir} is marked as immutable, cannot modify #{dir}/ }

      context 'nested file' do
        subject do
          instance.move_file(file, 's3://bucket/processed/')
        end
        it { expect { subject }.to raise_error RuntimeError, /#{dir} is marked as immutable, cannot modify #{file}/ }
      end
    end

    describe '#move_dir' do
      subject do
        instance.move_dir(dir, 's3://bucket/processed/')
      end

      it { expect { subject }.to raise_error RuntimeError, /#{dir} is marked as immutable, cannot modify #{dir}/ }
    end
  end

  describe '#cat' do
    context 'simple file' do
      before do
        instance.write('dog', new_file)
      end

      subject do
        instance.cat(new_file).string
      end

      it { should == 'dog' }
    end

    context 'result of directory glob' do
      before do
        instance.add_path(:new_dir, new_dir)
        instance.write('dog', instance.path(:new_dir, 'a', 'b', 'c', 'dog'))
      end

      subject do
        instance.cat(*instance.glob(instance.path(:new_dir, '**', '*'))).string
      end

      it { should == 'dog' }
    end
  end

  describe '#chown!' do
    context 'local' do
      subject(:operation) do
        instance.chown!(old_file)
      end
      it { expect { operation }.to_not raise_error }
    end

    context 'hdfs' do
      subject(:operation) do
        instance.chown!('file://' + old_file)
      end
      it { expect { operation }.to_not raise_error }
    end
  end
end

describe Masamune::Filesystem do
  let(:instance) { filesystem }

  it_behaves_like 'Filesystem'
end

describe Masamune::CachedFilesystem do
  let(:instance) { described_class.new(filesystem) }

  it_behaves_like 'Filesystem'
end
