package cmd

import (
	"io"

	"github.com/aquasecurity/starboard/pkg/starboard"
	"github.com/spf13/cobra"
	"k8s.io/cli-runtime/pkg/genericclioptions"
)

func NewGetCmd(buildInfo starboard.BuildInfo, cf *genericclioptions.ConfigFlags, outWriter io.Writer) *cobra.Command {
	getCmd := &cobra.Command{
		Use:   "get",
		Short: "Get security reports",
	}
	getCmd.AddCommand(NewGetVulnerabilitiesCmd(buildInfo.Executable, cf, outWriter))
	getCmd.AddCommand(NewGetConfigAuditCmd(buildInfo.Executable, cf, outWriter))
	getCmd.AddCommand(NewGetReportCmd(buildInfo, cf, outWriter))
	getCmd.PersistentFlags().StringP("output", "o", "yaml", "Output format. One of yaml|json")

	return getCmd
}
