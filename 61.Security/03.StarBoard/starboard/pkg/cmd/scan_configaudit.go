package cmd

import (
	"context"

	"github.com/aquasecurity/starboard/pkg/configauditreport"
	"github.com/aquasecurity/starboard/pkg/ext"
	"github.com/aquasecurity/starboard/pkg/generated/clientset/versioned"
	"github.com/aquasecurity/starboard/pkg/polaris"
	"github.com/aquasecurity/starboard/pkg/starboard"
	"github.com/spf13/cobra"
	"k8s.io/cli-runtime/pkg/genericclioptions"
	"k8s.io/client-go/kubernetes"
)

const (
	configAuditCmdShort = "Run a variety of checks to ensure that a given workload is configured using best practices"
)

func NewScanConfigAuditReportsCmd(cf *genericclioptions.ConfigFlags) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "configauditreports",
		Short: configAuditCmdShort,
		Args:  cobra.MaximumNArgs(1),
		RunE:  ScanConfigAuditReports(cf),
	}

	registerScannerOpts(cmd)

	return cmd
}

func ScanConfigAuditReports(cf *genericclioptions.ConfigFlags) func(cmd *cobra.Command, args []string) error {
	return func(cmd *cobra.Command, args []string) error {
		ctx := context.Background()
		ns, _, err := cf.ToRawKubeConfigLoader().Namespace()
		if err != nil {
			return err
		}
		mapper, err := cf.ToRESTMapper()
		if err != nil {
			return err
		}
		workload, gvk, err := WorkloadFromArgs(mapper, ns, args)
		if err != nil {
			return err
		}
		kubeConfig, err := cf.ToRESTConfig()
		if err != nil {
			return err
		}
		kubeClientset, err := kubernetes.NewForConfig(kubeConfig)
		if err != nil {
			return err
		}
		opts, err := getScannerOpts(cmd)
		if err != nil {
			return err
		}
		config, err := starboard.NewConfigManager(kubeClientset, starboard.NamespaceName).Read(ctx)
		if err != nil {
			return err
		}
		plugin := polaris.NewPlugin(ext.NewSystemClock(), config)
		scanner := configauditreport.NewScanner(starboard.NewScheme(), kubeClientset, opts, plugin)
		report, err := scanner.Scan(ctx, workload, gvk)
		if err != nil {
			return err
		}
		starboardClientset, err := versioned.NewForConfig(kubeConfig)
		if err != nil {
			return nil
		}
		writer := configauditreport.NewReadWriter(starboardClientset)
		return writer.Write(ctx, report)
	}
}
