#!/usr/bin/env python3
"""Parse JUnit XML and write results to GitHub Step Summary."""
import xml.etree.ElementTree as ET
import os
import sys


def main():
    """Main entry point for parsing JUnit XML results."""
    junit_file = sys.argv[1] if len(sys.argv) > 1 else 'test-results/junit.xml'

    try:
        tree = ET.parse(junit_file)
        root = tree.getroot()
        testsuite = root.find('.//testsuite')

        if testsuite is not None:
            tests = testsuite.get('tests', '0')
            failures = testsuite.get('failures', '0')
            errors = testsuite.get('errors', '0')
            time = testsuite.get('time', '0')

            summary_file = os.environ.get('GITHUB_STEP_SUMMARY', '/dev/stdout')
            with open(summary_file, 'a') as f:
                f.write("| Metric | Value |\n")
                f.write("|--------|-------|\n")
                f.write(f"| Total Tests | {tests} |\n")
                f.write(f"| Failures | {failures} |\n")
                f.write(f"| Errors | {errors} |\n")
                f.write(f"| Duration | {time}s |\n")
                f.write("\n")

                if int(failures) == 0 and int(errors) == 0:
                    f.write("✅ All tests passed!\n")
                else:
                    f.write("❌ Some tests failed. Check artifacts for details.\n")
        else:
            print("Warning: No testsuite element found in JUnit XML", file=sys.stderr)

    except FileNotFoundError:
        print(f"Error: JUnit XML file not found: {junit_file}", file=sys.stderr)
        sys.exit(1)
    except ET.ParseError as e:
        print(f"Error: Failed to parse JUnit XML: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: Failed to process test results: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
